import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/model/state/network_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/model/state/server/receiving_file.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/device_info_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/server/controller/receive_controller.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tv_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/dto/multicast_dto.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

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

  testWidgets('navigation survives repeated resumes and interruptions during motion', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    final controller = container.read(homePageControllerProvider).controller;
    for (var cycle = 0; cycle < 9; cycle++) {
      final target = HomeTab.values[(cycle + 1) % 3];
      await tester.tap(find.descendant(of: find.byType(M3eFloatingNavigationBar), matching: find.text(target.label)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.page, isNot(closeTo(target.index.toDouble(), 0.001)));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.view.physicalSize = Size(390, cycle.isEven ? 820 : 844);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _finishNavigation(tester);
      _expectNavigation(tester, container, target);
      expect(container.read(homePageControllerProvider).controller, same(controller));
      expect(controller.positions, hasLength(1));
      expect(tester.takeException(), isNull);
    }
    // Rapid reversals must settle on the last request, including a programmatic action.
    for (final target in [HomeTab.send, HomeTab.receive, HomeTab.settings, HomeTab.send]) {
      container.redux(homePageControllerProvider).dispatch(ChangeTabAction(target));
      await tester.pump(const Duration(milliseconds: 35));
    }
    await _finishNavigation(tester);
    _expectNavigation(tester, container, HomeTab.send);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('mobile navigation and rail remain synchronized through viewport and motion changes', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.settings);
    tester.view.physicalSize = const Size(900, 844);
    await tester.pump();
    await tester.pump();
    expect(find.byType(M3eFloatingNavigationBar), findsNothing);
    container.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.send));
    await _finishNavigation(tester);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, HomeTab.send.index);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.pump();
    _expectNavigation(tester, container, HomeTab.send);
    container.notifier(sleepProvider).setState((_) => true);
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.receive);
    _expectNavigation(tester, container, HomeTab.receive);
    expect(tester.widget<M3eFloatingNavigationBar>(find.byType(M3eFloatingNavigationBar)).animationsEnabled, isFalse);
    container.notifier(sleepProvider).setState((_) => false);
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.settings);
    _expectNavigation(tester, container, HomeTab.settings);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('route push and pop during tab motion preserve one Home PageView', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    final controller = container.read(homePageControllerProvider).controller;
    container.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings));
    await tester.pump(const Duration(milliseconds: 60));
    unawaited(
      container.read(navigationProvider).key.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Detail')))),
    );
    await _finishNavigation(tester);
    container.read(navigationProvider).key.currentState!.pop();
    await _finishNavigation(tester);
    _expectNavigation(tester, container, HomeTab.settings);
    expect(controller.positions, hasLength(1));
    await _tapTab(tester, HomeTab.send);
    _expectNavigation(tester, container, HomeTab.send);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Quick Save completion returns to the existing Home without duplicate PageViews', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer(initialSettings: _fixtureSettings(quickSave: true));
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.send);
    final homeState = tester.state(find.byType(HomePage));
    final controller = container.read(homePageControllerProvider).controller;
    ServerState? serverState = ServerState(
      alias: 'Fixture',
      port: 53317,
      https: false,
      webSendState: null,
      webUpload: false,
      webPin: null,
      session: ReceiveSessionState(
        sessionId: 'quick-save',
        status: SessionStatus.sending,
        sender: Device.empty,
        senderAlias: 'Fixture',
        files: {
          'file': ReceivingFile(
            file: FileDto(id: 'file', fileName: 'file.bin', size: 10, fileType: FileType.other, hash: null, preview: null, metadata: null),
            token: 'token',
            desiredName: 'file.bin',
            path: null,
            savedToGallery: false,
            errorMessage: null,
          ),
        },
        startTime: null,
        endTime: null,
        destinationDirectory: '',
        cacheDirectory: '',
        saveToGallery: false,
        createdDirectories: {},
      ),
    );
    final receiver = ReceiveController(
      ServerUtils(
        refFunc: () => container,
        getState: () => serverState!,
        getStateOrNull: () => serverState,
        setState: (builder) => serverState = builder(serverState),
      ),
    );
    // A null path exercises completion without an OpenFileDialog/native file launch.
    await receiver.onFileUploadResult(
      HttpServerFileUploadResultEvent(sessionId: 'quick-save', fileId: 'file', path: null, savedToGallery: false, error: null),
    );
    await _finishNavigation(tester);
    expect(serverState!.session, isNull);
    expect(find.byType(HomePage, skipOffstage: false), findsOneWidget);
    expect(tester.state(find.byType(HomePage)), same(homeState));
    expect(controller.positions, hasLength(1));
    _expectNavigation(tester, container, HomeTab.receive);
    await _tapTab(tester, HomeTab.settings);
    _expectNavigation(tester, container, HomeTab.settings);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('tab requests before PageView attachment select the initial page safely', (tester) async {
    final container = RefenaContainer();
    addTearDown(container.disposeContainer);
    container.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.send));
    container.redux(homePageControllerProvider).dispatch(ChangeTabAction(HomeTab.settings));
    final vm = container.read(homePageControllerProvider);
    await tester.pumpWidget(
      MaterialApp(
        home: PageView(controller: vm.controller, children: const [Text('Receive'), Text('Send'), Text('Settings')]),
      ),
    );
    await _finishNavigation(tester);
    expect(vm.currentTab, HomeTab.settings);
    expect(vm.controller.page, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android back returns root tabs Home before allowing system exit', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    for (final tab in [HomeTab.send, HomeTab.settings]) {
      await _tapTab(tester, tab);
      final scope = tester.widget<PopScope<Object?>>(find.byKey(const ValueKey('home-root-back-scope')));
      expect(scope.canPop, isFalse);
      await tester.binding.handlePopRoute();
      await _finishNavigation(tester);
      _expectNavigation(tester, container, HomeTab.receive);
      expect(tester.widget<PopScope<Object?>>(find.byKey(const ValueKey('home-root-back-scope'))).canPop, isTrue);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android back pops a nested route before returning its root tab Home', (tester) async {
    _setViewport(tester);
    final container = _navigationContainer();
    addTearDown(container.disposeContainer);
    await tester.pumpWidget(_navigationApp(container));
    await _finishNavigation(tester);
    await _tapTab(tester, HomeTab.settings);
    unawaited(
      container
          .read(navigationProvider)
          .key
          .currentState!
          .push(
            MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Nested settings'))),
          ),
    );
    await _finishNavigation(tester);
    expect(find.text('Nested settings'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _finishNavigation(tester);
    expect(find.text('Nested settings'), findsNothing);
    _expectNavigation(tester, container, HomeTab.settings);
    await tester.binding.handlePopRoute();
    await _finishNavigation(tester);
    _expectNavigation(tester, container, HomeTab.receive);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('Home PageController is disposed with its owning provider', () {
    final container = RefenaContainer();
    final controller = container.read(homePageControllerProvider).controller;
    container.disposeContainer();
    expect(() => controller.addListener(() {}), throwsFlutterError);
  });
}

Future<void> _finishNavigation(WidgetTester tester) async {
  // A zero-duration clock advance drains zero-delay completion timers before motion starts.
  await tester.pump(Duration.zero);
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
  final pill = find.byKey(const ValueKey('m3e-navigation-selected-pill'));
  expect(find.descendant(of: pill, matching: find.text(tab.label)), findsOneWidget);
  final decorated = tester.widget<DecoratedBox>(find.descendant(of: pill, matching: find.byType(DecoratedBox)).first);
  final scheme = Theme.of(tester.element(pill)).colorScheme;
  expect((decorated.decoration as BoxDecoration).color, scheme.primaryContainer);
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _navigationApp(RefenaContainer container) {
  Routerino.navigatorKey = container.read(navigationProvider).key;
  return RefenaScope.withContainer(
    container: container,
    ownsContainer: false,
    child: TranslationProvider(
      child: MaterialApp(
        navigatorKey: container.read(navigationProvider).key,
        theme: getTheme(ColorMode.oled, Colors.teal, Brightness.dark, null),
        home: RouterinoHome(builder: () => const HomePage(initialTab: HomeTab.receive, appStart: false)),
      ),
    ),
  );
}

RefenaContainer _navigationContainer({SettingsState? initialSettings}) {
  final settings = _FixtureSettingsService(initialSettings ?? _fixtureSettings());
  final persistence = MockPersistenceService();
  when(persistence.isSaveToHistory()).thenReturn(false);
  when(persistence.getReceiveHistory()).thenReturn([]);
  final info = DeviceInfoResult(deviceType: DeviceType.desktop, deviceModel: null, androidSdkInt: 28);
  return RefenaContainer(
    overrides: [
      settingsProvider.overrideWithNotifier((_) => settings),
      receiveHistoryProvider.overrideWithNotifier((_) => ReceiveHistoryService(persistence)),
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
