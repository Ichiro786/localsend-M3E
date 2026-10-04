import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';

import '../../fixtures/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('queued upload events cannot recreate a closed send', () {
    final fixture = TransferFixture(send: sendSession('send'));
    addTearDown(fixture.container.disposeContainer);
    fixture.sender.closeSession('send');
    for (final event in _events()) { fixture.sender.handleUploadEvent('send', event); }
    expect(fixture.container.read(fileTransferProvider).getData(), isEmpty);
  });

  for (final status in [SessionStatus.canceledByReceiver, SessionStatus.finished, SessionStatus.finishedWithErrors]) {
    test('queued upload events do not change a $status send', () {
      final fixture = TransferFixture(send: sendSession('send', status: status));
      addTearDown(fixture.container.disposeContainer);
      for (final event in _events()) { fixture.sender.handleUploadEvent('send', event); }
      expect(fixture.container.read(fileTransferProvider).getData(), isEmpty);
    });
  }

  test('normal upload events finish a file, ignoring duplicate failure and unknown files', () {
    final fixture = TransferFixture(send: sendSession('send'));
    addTearDown(fixture.container.disposeContainer);
    fixture.sender.handleUploadEvent('send', HttpUploadFileStartedEvent(fileId: 'outgoing'));
    fixture.sender.handleUploadEvent('send', HttpUploadFileProgressEvent(fileId: 'outgoing', progress: 0.5));
    fixture.sender.handleUploadEvent('send', HttpUploadFileFinishedEvent(fileId: 'outgoing'));
    fixture.sender.handleUploadEvent('send', HttpUploadFileFailedEvent(fileId: 'outgoing', error: 'duplicate'));
    fixture.sender.handleUploadEvent('send', HttpUploadFileFinishedEvent(fileId: 'unknown'));
    final transfer = fixture.container.read(fileTransferProvider);
    expect(transfer.getStatus(sessionId: 'send', fileId: 'outgoing'), FileStatus.finished);
    expect(transfer.getProgress(sessionId: 'send', fileId: 'outgoing'), 1);
    expect(transfer.getData()['send']!.keys, ['outgoing']);
  });
}

List<HttpUploadEvent> _events() => [HttpUploadFileStartedEvent(fileId: 'outgoing'),
  HttpUploadFileProgressEvent(fileId: 'outgoing', progress: 0.5), HttpUploadFileFinishedEvent(fileId: 'outgoing'),
  HttpUploadFileFailedEvent(fileId: 'outgoing', error: 'late error')];
