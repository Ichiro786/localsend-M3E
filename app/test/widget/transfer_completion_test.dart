import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/favorite_device.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/pages/receive_page.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/receive_results_provider.dart';
import 'package:localsend_app/util/notification_strings.dart';
import 'package:localsend_app/util/ui/transfer_route.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/rust/api/model.dart' as rust_model;
import 'package:localsend_isolates/rust/api/server.dart' show RegisterDtoV2, SessionEndReasonV2;
import 'package:localsend_isolates/util/rust.dart';
import 'package:localsend_isolates/util/transfer_notification.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

import '../fixtures/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    TransferNotification.init(notificationStrings);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.localsend.localsend_app/localsend'),
      (call) async => call.method == 'getDownloadsDirectory' ? Directory.systemTemp.path : true,
    );
  });
  tearDown(() {
    for (final name in ['plugins.flutter.io/path_provider', 'org.localsend.localsend_app/localsend', 'flutter.baseflow.com/permissions/methods']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });

  for (final size in [0, 10]) {
    testWidgets(
      'receive of $size bytes stays open with Auto Finish until Done, including repeated resumes',
      (tester) async {
        final fixture = TransferFixture(receive: receiveSession('receive', size: size));
        final navigator = await _app(tester, fixture);
        unawaited(navigator.push(_progress('receive', receiving: true)));
        await tester.pumpAndSettle();
        await fixture.receiver.onFileUploadResult(receiveResult('receive'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          await tester.pump(const Duration(seconds: 10));
          tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await tester.pumpAndSettle();
          expect(find.byType(ProgressPage), findsOneWidget);
          expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.finished);
        }
        expect(tester.widget<CustomProgressBar>(find.byType(CustomProgressBar).last).progress, 1);
        await _done(tester);
        expect(find.text('Parent route'), findsOneWidget);
        expect(fixture.server.closed, ['receive']);
        expect(fixture.container.read(receiveResultsProvider), isEmpty);
        expect(fixture.container.read(fileTransferProvider).getData(), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final mode in ['manual', 'quick-save', 'favorites', 'browser']) {
    testWidgets('$mode acceptance reaches a persistent completion and Done returns to its parent', (tester) async {
      final settings = transferSettings(
        quickSave: mode == 'quick-save',
        quickSaveFromFavorites: mode == 'favorites',
      ).copyWith(receiveViaLinkAutoAccept: mode == 'browser');
      final fixture = TransferFixture(
        settings: settings,
        favorites: mode == 'favorites'
            ? [const FavoriteDevice(id: 'favorite', fingerprint: 'sender-cert', ip: '192.168.1.2', port: 53317, alias: 'Favorite')]
            : [],
      );
      final navigator = await _app(tester, fixture);
      if (mode == 'browser') fixture.server.apply((s) => s!.copyWith(webUpload: true));
      await tester.runAsync(() => fixture.receiver.onPrepareUpload(_offer('accepted')));
      await tester.pumpAndSettle();
      if (mode == 'manual') {
        expect(find.byType(ReceivePage), findsOneWidget);
        await tester.tap(_button(t.general.accept, elevated: true));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ProgressPage), findsOneWidget);
      expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.sending);
      await fixture.receiver.onFileUploadResult(receiveResult('accepted'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(ProgressPage), findsOneWidget);
      expect(find.byType(ReceivePage, skipOffstage: false), findsNothing);
      await _done(tester);
      expect(navigator.canPop(), isFalse);
      expect(find.text('Parent route'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('a request aborted during directory lookup cannot reopen an acceptance page', (tester) async {
    final fixture = TransferFixture();
    final navigator = await _app(tester, fixture);
    final gate = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.localsend.localsend_app/localsend'),
      (_) => gate.future,
    );
    await tester.runAsync(() async {
      final pending = fixture.receiver.onPrepareUpload(_offer('aborted'));
      fixture.receiver.onPrepareUploadAborted(HttpServerPrepareUploadAbortedEvent(sessionId: 'aborted'));
      gate.complete(Directory.systemTemp.path);
      await pending;
    });
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isFalse);
    expect(fixture.container.read(serverProvider)!.session, isNull);
    expect(fixture.container.read(fileTransferProvider).getData(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('cancellation while storage permission is pending cannot accept the cancelled request', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('permission', status: SessionStatus.waiting), androidSdkInt: 28);
    await _app(tester, fixture);
    final entered = Completer<void>();
    final gate = Completer<Map<int, int>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) {
        entered.complete();
        return gate.future;
      },
    );
    await tester.runAsync(() async {
      final pending = fixture.receiver.acceptFileRequest({'file-0': 'file.bin'});
      await entered.future;
      fixture.receiver.onSessionEnd(HttpServerSessionEndEvent(sessionId: 'permission', reason: SessionEndReasonV2.cancelled));
      gate.complete({15: 1});
      await pending;
    });
    final decisions = fixture.observer.history.whereType<ActionDispatchedEvent>().where(
      (e) => e.action is IsolateHttpServerPrepareUploadDecisionAction,
    );
    expect(decisions, isEmpty);
    expect(fixture.container.read(serverProvider)!.session!.status, SessionStatus.canceledBySender);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('send Auto Finish remains enabled and closes only its own send session', (tester) async {
    final fixture = TransferFixture(send: sendSession('send', status: SessionStatus.finished));
    final navigator = await _app(tester, fixture);
    fixture.container.notifier(fileTransferProvider).setStatuses(sessionId: 'send', statuses: {'outgoing': FileStatus.finished});
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Parent route'), findsOneWidget);
    expect(fixture.sender.closed, ['send']);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('empty statuses do not count as completed sends', (tester) async {
    final fixture = TransferFixture(send: sendSession('send'));
    final navigator = await _app(tester, fixture);
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(ProgressPage), findsOneWidget);
    expect(fixture.sender.closed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('send Done does not close a simultaneous incoming receive', (tester) async {
    final fixture = TransferFixture(
      receive: receiveSession('receive'),
      send: sendSession('send', status: SessionStatus.finished),
      settings: transferSettings(autoFinish: false),
    );
    final navigator = await _app(tester, fixture);
    fixture.container.notifier(fileTransferProvider).setStatuses(sessionId: 'send', statuses: {'outgoing': FileStatus.finished});
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    expect(find.text(t.progressPage.titleSending), findsOneWidget);
    expect(find.text('outgoing.bin'), findsOneWidget);
    expect(find.text('receive-file-0.bin'), findsNothing);
    await _done(tester);
    expect(fixture.sender.closed, ['send']);
    expect(fixture.server.closed, isEmpty);
    expect(fixture.container.read(serverProvider)!.session!.sessionId, 'receive');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a covered send countdown cannot dismiss an incoming confirmation', (tester) async {
    final fixture = TransferFixture(
      receive: receiveSession('receive'),
      send: sendSession('send', status: SessionStatus.finished),
    );
    final navigator = await _app(tester, fixture);
    fixture.container.notifier(fileTransferProvider).setStatuses(sessionId: 'send', statuses: {'outgoing': FileStatus.finished});
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    unawaited(navigator.push(_progress('receive', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('receive'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(fixture.sender.closed, isEmpty);
    expect(find.text(t.progressPage.titleReceiving), findsOneWidget);
    await _done(tester);
    expect(find.text(t.progressPage.titleSending), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(fixture.sender.closed, ['send']);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('back-to-back receives retain each result and release it only when its route closes', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('first'));
    final navigator = await _app(tester, fixture);
    unawaited(navigator.push(_progress('first', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('first'));
    fixture.receiver.closeSession();
    fixture.server.setSession(receiveSession('next'));
    unawaited(navigator.push(_progress('next', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('next'));
    await tester.pumpAndSettle();
    expect(fixture.container.read(receiveResultsProvider).keys, containsAll(['first', 'next']));
    await _done(tester);
    expect(find.text('first-file-0.bin'), findsOneWidget);
    expect(find.text('next-file-0.bin'), findsNothing);
    expect(fixture.container.read(receiveResultsProvider).keys, ['first']);
    await _done(tester);
    expect(find.text('Parent route'), findsOneWidget);
    expect(fixture.container.read(receiveResultsProvider), isEmpty);
    expect(fixture.container.read(fileTransferProvider).getData(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Done on an older confirmation leaves a newer active receive untouched', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('first'));
    final navigator = await _app(tester, fixture);
    unawaited(navigator.push(_progress('first', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('first'));
    fixture.receiver.closeSession();
    fixture.server.setSession(receiveSession('next'));
    await tester.pumpAndSettle();
    await _done(tester);
    expect(fixture.server.closed, isEmpty);
    expect(fixture.container.read(serverProvider)!.session!.sessionId, 'next');
    expect(fixture.container.read(receiveResultsProvider), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a cancellation sheet cannot cancel a replacement receive', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('first'));
    final navigator = await _app(tester, fixture);
    unawaited(navigator.push(_progress('first', receiving: true)));
    await tester.pumpAndSettle();
    await tester.tap(_button(t.general.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(CancelSessionDialog), findsOneWidget);
    await fixture.receiver.onFileUploadResult(receiveResult('first'));
    fixture.receiver.closeSession();
    fixture.server.setSession(receiveSession('next'));
    await tester.tap(_button(t.general.cancel, elevated: true));
    await tester.pumpAndSettle();
    expect(fixture.server.cancelled, isEmpty);
    expect(fixture.container.read(serverProvider)!.session!.sessionId, 'next');
    expect(find.text('Parent route'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Done after receive errors cancels the native retry session', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('failed'));
    final navigator = await _app(tester, fixture);
    unawaited(navigator.push(_progress('failed', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('failed', error: 'disk full'));
    await tester.pumpAndSettle();
    await _done(tester);
    expect(fixture.server.cancelled, ['failed']);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('delayed send acceptance replaces its own route beneath an incoming confirmation', (tester) async {
    final fixture = TransferFixture();
    final navigator = await _app(tester, fixture);
    final request = MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outgoing request')));
    unawaited(navigator.push(request));
    await tester.pumpAndSettle();
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Incoming confirmation')))));
    await tester.pumpAndSettle();
    final progress = MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outgoing progress')));
    unawaited(replaceTransferRoute(request: request, progress: progress));
    await tester.pumpAndSettle();
    expect(find.text('Incoming confirmation'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Outgoing progress'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Parent route'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('read-and-close response removes only its outgoing request route', (tester) async {
    final fixture = TransferFixture();
    final navigator = await _app(tester, fixture);
    final request = MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outgoing request')));
    unawaited(navigator.push(request));
    await tester.pumpAndSettle();
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Incoming confirmation')))));
    await tester.pumpAndSettle();
    dismissTransferRoute(request);
    await tester.pumpAndSettle();
    expect(find.text('Incoming confirmation'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Parent route'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<NavigatorState> _app(WidgetTester tester, TransferFixture fixture) async {
  addTearDown(fixture.container.disposeContainer);
  final key = GlobalKey<NavigatorState>();
  Routerino.navigatorKey = key;
  await tester.pumpWidget(
    RefenaScope.withContainer(
      container: fixture.container,
      ownsContainer: false,
      child: TranslationProvider(
        child: MaterialApp(
          navigatorKey: key,
          theme: getTheme(ColorMode.oled, Colors.teal, Brightness.dark, null),
          home: const Scaffold(body: Text('Parent route')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

MaterialPageRoute<void> _progress(String id, {bool receiving = false}) => MaterialPageRoute<void>(
  builder: (_) => ProgressPage(showAppBar: false, closeSessionOnClose: true, sessionId: id, receiving: receiving),
);

Future<void> _done(WidgetTester tester) async {
  await tester.tap(_button(t.general.done));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

HttpServerPrepareUploadEvent _offer(String id) => HttpServerPrepareUploadEvent(
  sessionId: id,
  ip: '192.168.1.2',
  certFingerprint: 'sender-cert',
  info: const RegisterDtoV2(
    alias: 'Fixture',
    version: '2.1',
    fingerprint: 'sender-cert',
    port: 53317,
    protocol: rust_model.ProtocolType.http,
    download: false,
  ),
  files: {'file-0': transferFile('file-0').toRust()},
);

Finder _button(String label, {bool elevated = false}) => find
    .ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => elevated ? widget is ElevatedButton : widget is TextButton))
    .last;
