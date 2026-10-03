import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/network_state.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tv_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.localsend.localsend_app/localsend'),
      (_) async => true,
    );
  });
  tearDown(() {
    timeDilation = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('org.localsend.localsend_app/localsend'),
      null,
    );
  });

  testWidgets('Home selection stays subscribed after descendant-only viewport changes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.send);
    _expectNavigation(tester, container, HomeTab.send);

    // MediaQuery metrics can change when returning from Recents. ResponsiveBuilder
    // rebuilds independently of HomePage, exercising the production subscription flow.
    tester.view.physicalSize = const Size(390, 820);
    await tester.pump();
    await tester.pump();
    container.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings));
    await _finishNavigation(tester);
    _expectNavigation(tester, container, HomeTab.settings);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Future<void> _finishNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> _tapTab(WidgetTester tester, HomeTab tab) async {
  final nav = find.byType(M3eFloatingNavigationBar);
  await tester.tap(find.descendant(of: nav, matching: find.text(tab.label)));
  await _finishNavigation(tester);
}

void _expectNavigation(WidgetTester tester, RefenaContainer container, HomeTab tab) {
  final state = container.read(homePageControllerProvider);
  expect(state.currentTab, tab);
  expect(state.controller.page, closeTo(tab.index.toDouble(), 0.001));
  expect(tester.widget<M3eFloatingNavigationBar>(find.byType(M3eFloatingNavigationBar)).selectedIndex, tab.index);
}

Widget _navigationApp(RefenaContainer container) => RefenaScope.withContainer(
  container: container,
  child: TranslationProvider(child: MaterialApp(
    theme: getTheme(ColorMode.oled, Colors.teal, Brightness.dark, null),
    home: const HomePage(initialTab: HomeTab.receive, appStart: false),
  )),
);

RefenaContainer _navigationContainer() {
  final settings = _FixtureSettingsService(_fixtureSettings());
  final info = DeviceInfoResult(deviceType: DeviceType.desktop, deviceModel: null, androidSdkInt: 28);
  return RefenaContainer(
    overrides: [
      settingsProvider.overrideWithNotifier((_) => settings),
      serverProvider.overrideWithNotifier((_) => _BootstrapServer()),
      localIpProvider.overrideWithNotifier((_) => _NavigationLocalIpService(settings)),
      deviceInfoProvider.overrideWithBuilder((_) => info),
      tvProvider.overrideWithValue(false),
      versionProvider.overrideWithFuture((_) async => VersionData(version: 'test', buildNumber: '1')),
      nearbyDevicesProvider.overrideWithNotifier((_) => _NavigationNearbyDevicesService()),
      sendTabVmProvider.overrideWithBuilder(
        (_) => SendTabVm(
          sendMode: SendMode.single,
          selectedFiles: const [],
          localIps: const [],
          nearbyDevices: const [],
          favoriteDevices: const [],
          onTapAddress: (_) async {},
          onTapFavorite: (_) async {},
          onTapSendMode: (_, _) async {},
          onTapDevice: (_, _) async {},
          onTapDeviceMultiSend: (_, _) async {},
        ),
      ),
      settingsTabControllerProvider.overrideWithNotifier((_) => _FixtureSettingsTabController(settingsService: settings, deviceInfo: info)),
    ],
  );
}

// Stop bootstrap at the server boundary: these tests run the real HomePage,
// tab controller, animation provider, PageView and navigation, without native networking.
class _BootstrapServer extends ServerService {
  @override
  Future<ServerState?> startServerFromSettings() => Completer<ServerState?>().future;
}

class _NavigationLocalIpService extends LocalIpService {
  _NavigationLocalIpService(super.settingsService);
  @override
  NetworkState init() => const NetworkState(localIps: [], initialized: true);
  @override
  get initialAction => null;
}

class _NavigationNearbyDevicesService extends NearbyDevicesService {
  _NavigationNearbyDevicesService()
    : super(
        isolateController: IsolateController(
          initialState: _parentState(
            _fixtureSettings(),
            DeviceInfoResult(deviceType: DeviceType.desktop, deviceModel: null, androidSdkInt: 28),
          ),
        ),
        favoriteService: FavoritesService(MockPersistenceService()),
        discoveryLogs: DiscoveryLogger(),
      );
  @override
  NearbyDevicesState init() => const NearbyDevicesState(
    runningFavoriteScan: false,
    runningIps: {},
    signalingDevices: {},
    devices: {
      'fixture': Device(
        signalingId: null,
        ip: '192.168.1.2',
        version: '2.1',
        port: 53317,
        https: false,
        fingerprint: 'fixture',
        alias: 'Fixture',
        deviceModel: null,
        deviceType: DeviceType.desktop,
        download: false,
        channels: [],
      ),
    },
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
    colorMode: ColorMode.oled,
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
