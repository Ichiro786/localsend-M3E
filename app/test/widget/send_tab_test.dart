import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
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
    'picker grid retains two columns below 520 dp and three at 520 dp',
    (tester) async {
      final device = _fixtureDevice();
      final calls = <String>[];

      _setViewport(tester, const Size(551, 1000));
      await tester.pumpWidget(_sendApp(device: device, vm: _fixtureVm(device, calls)));
      await tester.pumpAndSettle();

      expect(find.byType(M3eSelectionCard), findsNWidgets(pickerOptions.length));
      var cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects[1].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[2].top, greaterThan(cardRects[0].bottom));
      expect(cardRects.first.height, 152);
      expect(tester.takeException(), isNull);

      _setViewport(tester, const Size(552, 1000));
      await tester.pumpWidget(_sendApp(device: device, vm: _fixtureVm(device, calls)));
      await tester.pumpAndSettle();

      cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects[1].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[2].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[3].top, greaterThan(cardRects[0].bottom));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'picker labels remain within the viewport at narrow width and larger text scale',
    (tester) async {
      final device = _fixtureDevice();
      final selectedModes = <SendMode>[];
      _setViewport(tester, const Size(320, 1100));

      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, [], selectedModes: selectedModes),
          textScale: 1.45,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(M3eSelectionCard), findsNWidgets(pickerOptions.length));
      for (final card in find.byType(M3eSelectionCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.height, closeTo(164.6, 0.1));
      }
      await tester.tap(find.byTooltip(t.sendTab.sendMode));
      await tester.pumpAndSettle();
      expect(find.text(t.sendTab.sendModes.single), findsOneWidget);
      expect(find.text(t.sendTab.sendModes.multiple), findsOneWidget);
      expect(find.text(t.sendTab.sendModes.link), findsOneWidget);
      expect(find.text(t.sendTab.sendModeHelp), findsOneWidget);
      await tester.tap(find.text(t.sendTab.sendModes.link));
      await tester.pumpAndSettle();
      expect(selectedModes, [SendMode.link]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'longest Mongolian picker title lays out fully at 320 dp and 2x text scale',
    (tester) async {
      await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.mn));
      final device = _fixtureDevice();
      _setViewport(tester, const Size(320, 1400));

      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, []),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      final longestLabel = pickerOptions
          .map((option) => option.label)
          .reduce(
            (longest, candidate) => candidate.runes.length > longest.runes.length ? candidate : longest,
          );
      expect(longestLabel, 'Санах ойгоос буулгах');
      expect(tester.takeException(), isNull);

      final title = find.text(longestLabel);
      expect(title, findsOneWidget);
      final card = find.ancestor(of: title, matching: find.byType(M3eSelectionCard));
      final cardRect = tester.getRect(card);
      final titleRect = tester.getRect(title);
      final titleWidget = tester.widget<Text>(title);
      expect(cardRect.height, greaterThan(180));
      expect(titleWidget.maxLines, isNull);
      expect(titleWidget.overflow, isNull);
      expect(titleRect.top, greaterThanOrEqualTo(cardRect.top));
      expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'nearby action labels and callbacks remain available with supplied device facts',
    (tester) async {
      final device = _fixtureDevice();
      final calls = <String>[];
      final selectedModes = <SendMode>[];
      _setViewport(tester, const Size(390, 1100));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _sendApp(
            device: device,
            vm: _fixtureVm(device, calls, selectedModes: selectedModes),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(t.sendTab.scan), findsOneWidget);
        expect(find.bySemanticsLabel(t.sendTab.manualSending), findsOneWidget);
        expect(find.bySemanticsLabel(t.dialogs.favoriteDialog.title), findsOneWidget);
        expect(find.bySemanticsLabel(t.sendTab.sendMode), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel(t.sendTab.manualSending)),
          matchesSemantics(label: t.sendTab.manualSending, isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(t.dialogs.favoriteDialog.title)),
          matchesSemantics(label: t.dialogs.favoriteDialog.title, isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel(t.sendTab.sendMode)),
          matchesSemantics(
            label: t.sendTab.sendMode,
            isButton: true,
            hasTapAction: true,
            hasFocusAction: true,
            isFocusable: true,
            hasExpandedState: true,
          ),
        );
        expect(find.text(device.alias), findsOneWidget);
        expect(find.text(device.deviceModel!), findsOneWidget);
        expect(find.text('HTTP'), findsOneWidget);

        final scanButton = find.ancestor(
          of: find.byIcon(Icons.sync),
          matching: find.byType(M3eIconButton),
        );
        expect(tester.getSize(scanButton).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(scanButton).height, greaterThanOrEqualTo(48));
        expect(tester.widget<M3eIconButton>(scanButton).selected, isTrue);
        for (final icon in [Icons.ads_click, Icons.favorite]) {
          final bounds = tester.getRect(find.widgetWithIcon(IconButton, icon));
          expect(bounds.width, greaterThanOrEqualTo(48));
          expect(bounds.height, greaterThanOrEqualTo(48));
        }

        await tester.tap(find.byTooltip(t.sendTab.manualSending));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(t.dialogs.favoriteDialog.title));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(t.sendTab.sendMode));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.sendTab.sendModes.link));
        await tester.pumpAndSettle();
        await tester.tap(find.text(device.alias));
        await tester.pumpAndSettle();

        expect(calls, ['manual', 'favorite', 'device']);
        expect(selectedModes, [SendMode.link]);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'picker and troubleshooting surfaces use the active light, dark, and OLED-compatible schemes',
    (tester) async {
      final device = _fixtureDevice();
      final schemes = [
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.light),
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: Brightness.dark),
        ColorScheme.dark().copyWith(
          primary: const Color(0xFFD0BCFF),
          onPrimary: const Color(0xFF381E72),
          primaryContainer: const Color(0xFF4F378B),
          onPrimaryContainer: const Color(0xFFEADDFF),
          surface: Colors.black,
          surfaceContainerLow: Colors.black,
        ),
      ];

      for (final scheme in schemes) {
        _setViewport(tester, const Size(390, 1100));
        final theme = ThemeData(useMaterial3: true, colorScheme: scheme);
        await tester.pumpWidget(
          _sendApp(
            device: device,
            vm: _fixtureVm(device, []),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();

        final selection = find.byType(M3eSelectionCard).first;
        final card = tester.widget<Card>(find.descendant(of: selection, matching: find.byType(Card)));
        expect(card.color, scheme.surfaceContainerLow.withValues(alpha: 0.84));
        final iconSurface = tester.widget<DecoratedBox>(
          find.descendant(
            of: selection,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox && widget.decoration is BoxDecoration && (widget.decoration as BoxDecoration).shape == BoxShape.circle,
            ),
          ),
        );
        expect((iconSurface.decoration as BoxDecoration).color, scheme.primary.withValues(alpha: 0.14));

        final troubleshoot = find.ancestor(
          of: find.text(t.troubleshootPage.title).last,
          matching: find.byType(Card),
        );
        expect(tester.widget<Card>(troubleshoot).color, scheme.surfaceContainerLow.withValues(alpha: 0.62));
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _sendApp({
  required Device device,
  required SendTabVm vm,
  double textScale = 1,
  ThemeData? theme,
}) {
  final settings = _fixtureSettings();
  return RefenaScope(
    overrides: [
      sendTabVmProvider.overrideWithBuilder((_) => vm),
      nearbyDevicesProvider.overrideWithNotifier((_) => _FixtureNearbyDevicesService(device)),
      settingsProvider.overrideWithNotifier((_) => _FixtureSettingsService(settings)),
      animationProvider.overrideWithBuilder((_) => false),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const SendTab(),
          ),
        ),
      ),
    ),
  );
}

SendTabVm _fixtureVm(Device device, List<String> calls, {List<SendMode>? selectedModes}) {
  return SendTabVm(
    sendMode: SendMode.single,
    selectedFiles: const [],
    localIps: const [],
    nearbyDevices: [device],
    favoriteDevices: const [],
    onTapAddress: (_) async => calls.add('manual'),
    onTapFavorite: (_) async => calls.add('favorite'),
    onTapSendMode: (_, mode) async => selectedModes?.add(mode),
    onTapDevice: (_, _) async => calls.add('device'),
    onTapDeviceMultiSend: (_, _) async => calls.add('multi-device'),
  );
}

Device _fixtureDevice() {
  return const Device(
    signalingId: null,
    ip: '192.168.1.42',
    version: '2.1.0',
    port: 53317,
    https: false,
    fingerprint: 'test-device-fingerprint',
    alias: 'Studio device',
    deviceModel: 'LocalSend test desktop',
    deviceType: DeviceType.desktop,
    download: false,
    channels: [HttpChannel(host: '192.168.1.42', port: 53317, https: false)],
  );
}

SettingsState _fixtureSettings() {
  return SettingsState(
    showToken: '',
    alias: 'LocalSend fixture',
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
    quickSave: false,
    quickSaveFromFavorites: false,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: false,
    sendMode: SendMode.single,
    saveWindowPlacement: false,
    enableAnimations: false,
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

  _FixtureSettingsService(this.initialSettings) : super(MockPersistenceService());

  @override
  SettingsState init() => initialSettings;
}

class _FixtureNearbyDevicesService extends NearbyDevicesService {
  final Device device;

  _FixtureNearbyDevicesService(this.device)
    : super(
        isolateController: IsolateController(initialState: _parentState()),
        favoriteService: FavoritesService(MockPersistenceService()),
        discoveryLogs: DiscoveryLogger(),
      );

  @override
  NearbyDevicesState init() => NearbyDevicesState(
    runningFavoriteScan: false,
    runningIps: const {},
    devices: {device.fingerprint: device},
    signalingDevices: const {},
  );
}

ParentIsolateState _parentState() {
  final settings = _fixtureSettings();
  final deviceInfo = DeviceInfoResult(
    deviceType: DeviceType.desktop,
    deviceModel: null,
    androidSdkInt: null,
  );
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
      protocol: ProtocolType.http,
      multicastGroup: settings.multicastGroup,
      discoveryTimeout: settings.discoveryTimeout,
      serverRunning: false,
      download: false,
    ),
  );
}
