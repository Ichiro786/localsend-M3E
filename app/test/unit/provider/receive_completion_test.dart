import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/receive_results_provider.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/rust/api/server.dart' show SessionEndReasonV2;
import 'package:localsend_isolates/util/rust.dart';
import 'package:mockito/mockito.dart';

import '../../fixtures/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in ['manual', 'quick-save', 'favorites']) {
    test('$mode successful receive stays completed until explicit dismissal', () async {
      final fixture = TransferFixture(
        receive: receiveSession('receive'),
        settings: transferSettings(quickSave: mode == 'quick-save', quickSaveFromFavorites: mode == 'favorites'),
      );
      addTearDown(fixture.container.disposeContainer);
      await fixture.receiver.onFileUploadResult(receiveResult('receive'));
      // Flush the original zero-duration Quick Save dismissal.
      await Future<void>.delayed(Duration.zero);
      final session = fixture.container.read(serverProvider)!.session!;
      expect(session.status, SessionStatus.finished);
      expect(session.files['file-0']!.path, '/downloads/receive-file-0.bin');
      expect(fixture.container.read(fileTransferProvider).getStatuses('receive'), [FileStatus.finished]);
      expect(fixture.container.read(receiveResultsProvider)['receive']!.status, SessionStatus.finished);
    });
  }

  test('multi-file receive finishes only after every accepted file, and retains gallery metadata', () async {
    final fixture = TransferFixture(receive: receiveSession('multi', count: 3));
    addTearDown(fixture.container.disposeContainer);
    fixture.container
        .notifier(fileTransferProvider)
        .setStatuses(sessionId: 'multi', statuses: {'file-0': FileStatus.sending, 'file-1': FileStatus.sending, 'file-2': FileStatus.skipped});
    await fixture.receiver.onFileUploadResult(receiveResult('multi'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.sending);
    await fixture.receiver.onFileUploadResult(receiveResult('multi', fileId: 'file-1', gallery: true));
    final session = fixture.container.read(serverProvider)!.session!;
    expect(session.status, SessionStatus.finished);
    expect(session.files['file-1']!.savedToGallery, isTrue);
    expect(session.files['file-1']!.path, isNull);
  });

  test('completion publishes before delayed history; its continuation cannot touch a new session', () async {
    final fixture = TransferFixture(receive: receiveSession('first'));
    addTearDown(fixture.container.disposeContainer);
    final gate = Completer<void>();
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) => gate.future);
    final pending = fixture.receiver.onFileUploadResult(receiveResult('first'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
    fixture.receiver.closeSession();
    fixture.server.setSession(receiveSession('next'));
    gate.complete();
    await pending;
    expect(fixture.container.read(serverProvider)!.session!.sessionId, 'next');
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.sending);
    expect(fixture.container.read(receiveResultsProvider)['first']!.files['file-0']!.path, '/downloads/first-file-0.bin');
    expect(fixture.container.read(fileTransferProvider).getStatuses('first'), [FileStatus.finished]);
  });

  test('history write errors leave a successful receive completed', () async {
    final fixture = TransferFixture(receive: receiveSession('disk'));
    addTearDown(fixture.container.disposeContainer);
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) async => throw StateError('history unavailable'));
    await fixture.receiver.onFileUploadResult(receiveResult('disk'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
    expect(fixture.container.read(receiveResultsProvider), contains('disk'));
  });

  test('simultaneous file completions serialize history writes without delaying receive completion', () async {
    final fixture = TransferFixture(receive: receiveSession('concurrent', count: 2));
    addTearDown(fixture.container.disposeContainer);
    fixture.container
        .notifier(fileTransferProvider)
        .setStatuses(sessionId: 'concurrent', statuses: {'file-0': FileStatus.sending, 'file-1': FileStatus.sending});
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    final gate = Completer<void>();
    final started = Completer<void>();
    var writes = 0;
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) async {
      writes++;
      if (writes == 1) {
        started.complete();
        await gate.future;
      }
    });
    final first = fixture.receiver.onFileUploadResult(receiveResult('concurrent'));
    await started.future;
    final second = fixture.receiver.onFileUploadResult(receiveResult('concurrent', fileId: 'file-1'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
    await Future<void>.delayed(Duration.zero);
    expect(writes, 1);
    gate.complete();
    await Future.wait([first, second]);
    expect(fixture.container.read(receiveHistoryProvider).map((e) => e.id), containsAll(['file-0', 'file-1']));
    expect(writes, 2);
  });

  test('clearing history waits for an in-flight write and does not resurrect its entry', () async {
    final fixture = TransferFixture(receive: receiveSession('clear'));
    addTearDown(fixture.container.disposeContainer);
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    final gate = Completer<void>();
    final started = Completer<void>();
    var writes = 0;
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) async {
      writes++;
      if (writes == 1) {
        started.complete();
        await gate.future;
      }
    });
    final result = fixture.receiver.onFileUploadResult(receiveResult('clear'));
    await started.future;
    final clear = fixture.container.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
    gate.complete();
    await Future.wait([result, clear]);
    expect(fixture.container.read(receiveHistoryProvider), isEmpty);
    verify(fixture.persistence.setReceiveHistory([])).called(1);
  });

  test('a failed history write releases the next queued completion', () async {
    final fixture = TransferFixture(receive: receiveSession('queued', count: 2));
    addTearDown(fixture.container.disposeContainer);
    fixture.container
        .notifier(fileTransferProvider)
        .setStatuses(sessionId: 'queued', statuses: {'file-0': FileStatus.sending, 'file-1': FileStatus.sending});
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    var writes = 0;
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) async {
      if (++writes == 1) throw StateError('one failed write');
    });
    await Future.wait([
      fixture.receiver.onFileUploadResult(receiveResult('queued')),
      fixture.receiver.onFileUploadResult(receiveResult('queued', fileId: 'file-1')),
    ]);
    expect(writes, 2);
    expect(fixture.container.read(receiveHistoryProvider).single.id, 'file-1');
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
  });

  test('duplicate results do not overwrite saved files or add duplicate history', () async {
    final fixture = TransferFixture(receive: receiveSession('duplicate', count: 2));
    addTearDown(fixture.container.disposeContainer);
    when(fixture.persistence.isSaveToHistory()).thenReturn(true);
    when(fixture.persistence.setReceiveHistory(any)).thenAnswer((_) async {});
    await fixture.receiver.onFileUploadResult(receiveResult('duplicate'));
    await fixture.receiver.onFileUploadResult(receiveResult('duplicate', error: 'late error'));
    expect(fixture.container.read(serverProvider)!.session!.files['file-0']!.errorMessage, isNull);
    expect(fixture.container.read(receiveHistoryProvider), hasLength(1));
    verify(fixture.persistence.setReceiveHistory(any)).called(1);
  });

  test('failed receive can retry to success without losing its confirmation', () async {
    final fixture = TransferFixture(receive: receiveSession('retry'));
    addTearDown(fixture.container.disposeContainer);
    await fixture.receiver.onFileUploadResult(receiveResult('retry', error: 'network interrupted'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finishedWithErrors);
    fixture.receiver.onFileUpload(HttpServerFileUploadEvent(sessionId: 'retry', fileId: 'file-0', file: transferFile('file-0').toRust()));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.sending);
    await fixture.receiver.onFileUploadResult(receiveResult('retry'));
    expect(fixture.container.read(receiveResultsProvider)['retry']!.status, SessionStatus.finished);
    expect(fixture.container.read(serverProvider)!.session!.files['file-0']!.errorMessage, isNull);
  });

  test('late progress and cancellation cannot downgrade a successful receive', () async {
    final fixture = TransferFixture(receive: receiveSession('finished'));
    addTearDown(fixture.container.disposeContainer);
    await fixture.receiver.onFileUploadResult(receiveResult('finished'));
    fixture.receiver.onFileUploadProgress(HttpServerFileUploadProgressEvent(sessionId: 'finished', fileId: 'file-0', progress: 0.1));
    fixture.receiver.onSessionEnd(HttpServerSessionEndEvent(sessionId: 'finished', reason: SessionEndReasonV2.cancelled));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
    expect(fixture.container.read(fileTransferProvider).getProgress(sessionId: 'finished', fileId: 'file-0'), 1);
  });

  test('cancelled receive ignores delayed results and preserves cancellation', () async {
    final fixture = TransferFixture(receive: receiveSession('cancelled'));
    addTearDown(fixture.container.disposeContainer);
    fixture.receiver.onSessionEnd(HttpServerSessionEndEvent(sessionId: 'cancelled', reason: SessionEndReasonV2.cancelled));
    await fixture.receiver.onFileUploadResult(receiveResult('cancelled'));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.canceledBySender);
    expect(fixture.container.read(receiveResultsProvider)['cancelled']!.status, SessionStatus.canceledBySender);
    expect(fixture.container.read(receiveHistoryProvider), isEmpty);
  });

  test('events from a previous session cannot change a replacement receive', () async {
    final fixture = TransferFixture(receive: receiveSession('new'));
    addTearDown(fixture.container.disposeContainer);
    await fixture.receiver.onFileUploadResult(receiveResult('old'));
    fixture.receiver.onFileUploadProgress(HttpServerFileUploadProgressEvent(sessionId: 'old', fileId: 'file-0', progress: 1));
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.sending);
    expect(fixture.container.read(fileTransferProvider).getData(), isNot(contains('old')));
  });
}
