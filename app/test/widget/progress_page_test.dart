import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/send/sending_file.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/progress_page.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/file_status.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets(
    'the final sending rows scroll above the expanded Advanced card',
    (tester) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const sessionId = 'widget-test-session';
      const fileCount = 16;
      final files = {
        for (var i = 0; i < fileCount; i++)
          'file-$i': SendingFile(
            file: FileDto(
              id: 'file-$i',
              fileName: 'transfer-item-$i.txt',
              size: 1024,
              fileType: FileType.text,
              hash: null,
              preview: null,
              metadata: null,
            ),
            token: 'token-$i',
            thumbnail: null,
            asset: null,
            path: null,
            bytes: null,
            errorMessage: null,
          ),
      };
      final session = SendSessionState(
        sessionId: sessionId,
        remoteSessionId: 'remote-session',
        background: false,
        status: SessionStatus.sending,
        target: Device.empty,
        files: files,
        hashedFileCount: fileCount,
        startTime: null,
        endTime: null,
        sendingTasks: const [],
        errorMessage: null,
      );

      await tester.pumpWidget(
        RefenaScope(
          overrides: [
            sendProvider.overrideWithNotifier((_) => _FixtureSendNotifier(sessionId, session)),
            fileTransferProvider.overrideWithNotifier((_) {
              final notifier = FileTransferNotifier();
              notifier.setStatuses(
                sessionId: sessionId,
                statuses: {for (final id in files.keys) id: FileStatus.sending},
              );
              return notifier;
            }),
            settingsProvider.overrideWithNotifier((_) => _FixtureSettingsService()),
          ],
          child: MaterialApp(
            theme: ThemeData(inputDecorationTheme: const InputDecorationTheme(fillColor: Colors.white)),
            home: const ProgressPage(
              showAppBar: false,
              closeSessionOnClose: false,
              sessionId: sessionId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      final listView = find.byType(ListView);
      final scrollable = find.descendant(of: listView, matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      final lastRow = _fileRow('transfer-item-15.txt');
      final previousRow = _fileRow('transfer-item-14.txt');
      final advancedCard = tester.getRect(find.byType(Card));
      expect(tester.getRect(lastRow).bottom, lessThanOrEqualTo(advancedCard.top));
      expect(tester.getRect(previousRow).bottom, lessThanOrEqualTo(advancedCard.top));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Finder _fileRow(String fileName) {
  return find.ancestor(of: find.text(fileName), matching: find.byType(InkWell)).first;
}

class _FixtureSendNotifier extends SendNotifier {
  final String sessionId;
  final SendSessionState session;

  _FixtureSendNotifier(this.sessionId, this.session);

  @override
  Map<String, SendSessionState> init() => {sessionId: session};
}

class _FixtureSettingsService extends SettingsService {
  _FixtureSettingsService() : super(MockPersistenceService());

  @override
  SettingsState init() => const SettingsState(
    showToken: '',
    alias: '',
    theme: ThemeMode.system,
    colorMode: ColorMode.system,
    customColor: Color(0xFF000000),
    locale: AppLocale.en,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: null,
    saveToGallery: false,
    saveToHistory: false,
    quickSave: false,
    quickSaveFromFavorites: false,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: false,
    sendMode: SendMode.multiple,
    saveWindowPlacement: false,
    deviceType: DeviceType.desktop,
    deviceModel: null,
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: false,
    verifyChecksums: false,
    discoveryTimeout: 5,
    advancedSettings: false,
  );
}
