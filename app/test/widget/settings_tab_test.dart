import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tv_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:localsend_isolates/model/dto/multicast_dto.dart';
import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets(
    'Settings rows remain readable at narrow width with larger text scaling',
    (tester) async {
      _setViewport(tester, const Size(320, 900));
      final settings = _FixtureSettingsService(_fixtureSettings());

      await tester.pumpWidget(_settingsApp(settings, textScale: 1.65));
      await tester.pumpAndSettle();

      expect(find.byType(M3eSettingsRow), findsWidgets);
      expect(find.byType(M3eSettingsIcon), findsWidgets);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.text(t.settingsTab.receive.quickSave), findsOneWidget);
      expect(tester.takeException(), isNull);

      final quickSaveRow = find.ancestor(
        of: find.text(t.settingsTab.receive.quickSave),
        matching: find.byType(M3eSettingsRow),
      );
      final quickSaveSwitch = find.descendant(
        of: quickSaveRow,
        matching: find.byType(M3eExpressiveSwitch),
      );
      final titleRect = tester.getRect(find.text(t.settingsTab.receive.quickSave));
      final switchRect = tester.getRect(quickSaveSwitch);
      expect(switchRect.height, 48);
      expect(switchRect.top, greaterThan(titleRect.bottom));
      expect(switchRect.left, greaterThanOrEqualTo(0));
      expect(switchRect.right, lessThanOrEqualTo(320));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'quick-save row keeps its semantic state and persistence callback',
    (tester) async {
      _setViewport(tester, const Size(390, 900));
      final settings = _FixtureSettingsService(_fixtureSettings(quickSave: true));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_settingsApp(settings));
        await tester.pumpAndSettle();

        final quickSaveRow = find.ancestor(
          of: find.text(t.settingsTab.receive.quickSave),
          matching: find.byType(M3eSettingsRow),
        );
        final quickSaveSwitch = find.descendant(
          of: quickSaveRow,
          matching: find.byType(M3eExpressiveSwitch),
        );
        expect(find.bySemanticsLabel('${t.settingsTab.receive.quickSave}, ${t.general.on}'), findsOneWidget);

        await tester.ensureVisible(quickSaveSwitch);
        await tester.tap(quickSaveSwitch);
        await tester.pumpAndSettle();

        expect(settings.quickSaveUpdates, [false]);
        expect(settings.quickSaveFromFavoritesUpdates, isEmpty);
        expect(settings.state.quickSave, isFalse);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.bySemanticsLabel('${t.settingsTab.receive.quickSave}, ${t.general.off}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'enabling quick save disables favorites mode and opens the existing notice',
    (tester) async {
      _setViewport(tester, const Size(390, 900));
      final settings = _FixtureSettingsService(
        _fixtureSettings(quickSaveFromFavorites: true),
      );

      await tester.pumpWidget(_settingsApp(settings));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_switchInRow(t.settingsTab.receive.quickSave));
      await tester.tap(_switchInRow(t.settingsTab.receive.quickSave));
      await tester.pumpAndSettle();

      expect(settings.quickSaveUpdates, [true]);
      expect(settings.quickSaveFromFavoritesUpdates, [false]);
      expect(settings.state.quickSave, isTrue);
      expect(settings.state.quickSaveFromFavorites, isFalse);
      expect(find.byType(QuickSaveNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'enabling favorites mode disables quick save and opens its existing notice',
    (tester) async {
      _setViewport(tester, const Size(390, 900));
      final settings = _FixtureSettingsService(_fixtureSettings(quickSave: true));

      await tester.pumpWidget(_settingsApp(settings));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_switchInRow(t.settingsTab.receive.quickSaveFromFavorites));
      await tester.tap(_switchInRow(t.settingsTab.receive.quickSaveFromFavorites));
      await tester.pumpAndSettle();

      expect(settings.quickSaveFromFavoritesUpdates, [true]);
      expect(settings.quickSaveUpdates, [false]);
      expect(settings.state.quickSave, isFalse);
      expect(settings.state.quickSaveFromFavorites, isTrue);
      expect(find.byType(QuickSaveFromFavoritesNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Finder _switchInRow(String label) {
  final row = find.ancestor(
    of: find.text(label),
    matching: find.byType(M3eSettingsRow),
  );
  return find.descendant(of: row, matching: find.byType(M3eExpressiveSwitch));
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _settingsApp(_FixtureSettingsService settings, {double textScale = 1}) {
  final deviceInfo = DeviceInfoResult(
    deviceType: DeviceType.desktop,
    deviceModel: null,
    androidSdkInt: null,
  );
  final parentState = _parentState(settings.initialSettings, deviceInfo);

  return RefenaScope(
    overrides: [
      settingsProvider.overrideWithNotifier((_) => settings),
      parentIsolateProvider.overrideWithNotifier((_) => IsolateController(initialState: parentState)),
      settingsTabControllerProvider.overrideWithNotifier((ref) {
        final settingsService = ref.notifier(settingsProvider);
        return _FixtureSettingsTabController(
          settingsService: settingsService,
          deviceInfo: deviceInfo,
        );
      }),
      tvProvider.overrideWithValue(false),
      versionProvider.overrideWithFuture(
        (_) async => VersionData(version: 'test', buildNumber: '1'),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const SettingsTab(),
          ),
        ),
      ),
    ),
  );
}

ParentIsolateState _parentState(SettingsState settings, DeviceInfoResult deviceInfo) {
  return ParentIsolateState.initial(
    SyncState(
      rootIsolateToken: Object(),
      securityContext: const StoredSecurityContext(
        privateKey: '',
        publicKey: '',
        certificate: '',
        certificateHash: '',
      ),
      deviceInfo: deviceInfo,
      alias: settings.alias,
      port: settings.port,
      networkWhitelist: settings.networkWhitelist,
      networkBlacklist: settings.networkBlacklist,
      protocol: settings.https ? ProtocolType.https : ProtocolType.http,
      multicastGroup: settings.multicastGroup,
      discoveryTimeout: settings.discoveryTimeout,
      serverRunning: false,
      download: false,
    ),
  );
}

SettingsState _fixtureSettings({bool quickSave = false, bool quickSaveFromFavorites = false}) {
  return SettingsState(
    showToken: '',
    alias: 'LocalSend test device',
    theme: ThemeMode.system,
    colorMode: ColorMode.system,
    customColor: const Color(0xFF000000),
    locale: AppLocale.en,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: null,
    saveToGallery: false,
    saveToHistory: false,
    quickSave: quickSave,
    quickSaveFromFavorites: quickSaveFromFavorites,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: false,
    sendMode: SendMode.multiple,
    saveWindowPlacement: false,
    enableAnimations: true,
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

class _FixtureSettingsService extends SettingsService {
  final SettingsState initialSettings;
  final List<bool> quickSaveUpdates = [];
  final List<bool> quickSaveFromFavoritesUpdates = [];

  _FixtureSettingsService(this.initialSettings) : super(MockPersistenceService());

  @override
  SettingsState init() => initialSettings;

  @override
  Future<void> setQuickSave(bool quickSave) async {
    quickSaveUpdates.add(quickSave);
    state = state.copyWith(quickSave: quickSave);
  }

  @override
  Future<void> setQuickSaveFromFavorites(bool quickSaveFromFavorites) async {
    quickSaveFromFavoritesUpdates.add(quickSaveFromFavorites);
    state = state.copyWith(quickSaveFromFavorites: quickSaveFromFavorites);
  }
}

class _FixtureSettingsTabController extends SettingsTabController {
  final SettingsService _settingsService;
  final DeviceInfoResult _deviceInfo;

  _FixtureSettingsTabController({
    required super.settingsService,
    required DeviceInfoResult deviceInfo,
  }) : _settingsService = settingsService,
       _deviceInfo = deviceInfo,
       super(
         serverNotifier: ServerService(),
         isolateController: IsolateController(initialState: _parentState(settingsService.state, deviceInfo)),
         localIpService: LocalIpService(settingsService),
         initialDeviceInfo: deviceInfo,
         supportsDynamicColors: false,
       );

  @override
  SettingsTabVm init() {
    final settings = _settingsService.state;
    return SettingsTabVm(
      advanced: settings.advancedSettings,
      aliasController: TextEditingController(text: settings.alias),
      deviceModelController: TextEditingController(text: settings.deviceModel ?? ''),
      portController: TextEditingController(text: settings.port.toString()),
      timeoutController: TextEditingController(text: settings.discoveryTimeout.toString()),
      multicastController: TextEditingController(text: settings.multicastGroup),
      settings: settings,
      serverState: null,
      deviceInfo: _deviceInfo,
      colorModes: ColorMode.values,
      autoStart: false,
      autoStartLaunchHidden: false,
      showInContextMenu: false,
      onChangeTheme: (_, _) {},
      onChangeColorMode: (_, _) {},
      onTapLanguage: (_) {},
      onToggleAutoStart: (_) {},
      onToggleAutoStartLaunchHidden: (_) {},
      onToggleShowInContextMenu: (_) {},
      onTapRestartServer: (_) {},
      onTapStartServer: (_) {},
      onTapStopServer: () {},
      onTapAdvanced: (_) {},
    );
  }

  @override
  get initialAction => _FixtureSettingsTabWatchAction();
}

class _FixtureSettingsTabWatchAction extends WatchAction<_FixtureSettingsTabController, SettingsTabVm> {
  @override
  SettingsTabVm reduce() {
    return state.copyWith(settings: ref.watch(settingsProvider));
  }
}
