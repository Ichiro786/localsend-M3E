import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/receive_results_provider.dart';
import 'package:localsend_app/util/ui/transfer_route.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/dialogs/cancel_session_dialog.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../fixtures/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  for (final size in [0, 10]) {
    testWidgets('receive of $size bytes stays open with Auto Finish until Done, including repeated resumes', (tester) async {
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
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('send Auto Finish remains enabled and closes only its own send session', (tester) async {
    final fixture = TransferFixture(send: sendSession('send', status: SessionStatus.finished));
    final navigator = await _app(tester, fixture);
    fixture.container.notifier(fileTransferProvider).setStatuses(sessionId: 'send', statuses: {'outgoing': FileStatus.finished});
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) { await tester.pump(const Duration(seconds: 1)); }
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
    for (var i = 0; i < 5; i++) { await tester.pump(const Duration(seconds: 1)); }
    expect(find.byType(ProgressPage), findsOneWidget);
    expect(fixture.sender.closed, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('send Done does not close a simultaneous incoming receive', (tester) async {
    final fixture = TransferFixture(receive: receiveSession('receive'), send: sendSession('send', status: SessionStatus.finished),
      settings: transferSettings(autoFinish: false));
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
    final fixture = TransferFixture(receive: receiveSession('receive'), send: sendSession('send', status: SessionStatus.finished));
    final navigator = await _app(tester, fixture);
    fixture.container.notifier(fileTransferProvider).setStatuses(sessionId: 'send', statuses: {'outgoing': FileStatus.finished});
    unawaited(navigator.push(_progress('send')));
    await tester.pumpAndSettle();
    unawaited(navigator.push(_progress('receive', receiving: true)));
    await tester.pumpAndSettle();
    await fixture.receiver.onFileUploadResult(receiveResult('receive'));
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(seconds: 1)); }
    await tester.pumpAndSettle();
    expect(fixture.sender.closed, isEmpty);
    expect(find.text(t.progressPage.titleReceiving), findsOneWidget);
    await _done(tester);
    expect(find.text(t.progressPage.titleSending), findsOneWidget);
    for (var i = 0; i < 4; i++) { await tester.pump(const Duration(seconds: 1)); }
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
    await tester.tap(find.widgetWithText(TextButton, t.general.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(CancelSessionDialog), findsOneWidget);
    await fixture.receiver.onFileUploadResult(receiveResult('first'));
    fixture.receiver.closeSession();
    fixture.server.setSession(receiveSession('next'));
    await tester.tap(find.widgetWithText(ElevatedButton, t.general.cancel));
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
  await tester.pumpWidget(RefenaScope.withContainer(container: fixture.container, ownsContainer: false,
    child: TranslationProvider(child: MaterialApp(navigatorKey: key,
      theme: getTheme(ColorMode.oled, Colors.teal, Brightness.dark, null), home: const Scaffold(body: Text('Parent route'))))));
  await tester.pumpAndSettle();
  return key.currentState!;
}

MaterialPageRoute<void> _progress(String id, {bool receiving = false}) => MaterialPageRoute<void>(builder: (_) =>
  ProgressPage(showAppBar: false, closeSessionOnClose: true, sessionId: id, receiving: receiving));

Future<void> _done(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, t.general.done).last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
