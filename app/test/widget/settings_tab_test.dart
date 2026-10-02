import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/pages/tabs/settings_tab_vm.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/tv_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
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

      await tester.pumpWidget(_settingsApp(settings, textScale: 2));
      await tester.pumpAndSettle();

      expect(find.byType(M3eSettingsRow), findsWidgets);
      expect(find.byType(M3eSettingsIcon), findsWidgets);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.text(t.settingsTab.receive.quickSave), findsOneWidget);
      expect(
        t.settingsTab.receive.quickSaveDescription,
        'Automatically accept file requests from anyone on your local network and save the received files',
      );
      expect(
        find.text(t.settingsTab.receive.quickSaveDescription),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final quickSaveRow = find.ancestor(
        of: find.text(t.settingsTab.receive.quickSave),
        matching: find.byType(M3eSettingsRow),
      );
      final quickSaveSwitch = find.descendant(
        of: quickSaveRow,
        matching: find.byType(M3eExpressiveSwitch),
      );
      final titleRect = tester.getRect(
        find.text(t.settingsTab.receive.quickSave),
      );
      final switchRect = tester.getRect(quickSaveSwitch);
      expect(switchRect.height, 48);
      expect(switchRect.top, greaterThan(titleRect.bottom));
      expect(switchRect.left, greaterThanOrEqualTo(0));
      expect(switchRect.right, lessThanOrEqualTo(320));
      await tester.ensureVisible(quickSaveSwitch);
      await tester.tap(quickSaveSwitch);
      await tester.pumpAndSettle();
      expect(settings.quickSaveUpdates, [true]);
      expect(find.byType(QuickSaveNotice), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Settings reveal transitions honor saved and system reduced motion',
    (tester) async {
      addTearDown(() => timeDilation = 1.0);
      const serverState = ServerState(
        alias: 'Currently running server',
        port: 53317,
        https: false,
        session: null,
        webSendState: null,
        webUpload: false,
        webPin: null,
      );
      const scenarios = [
        (animationsEnabled: true, disableAnimations: false, motionAllowed: true),
        (animationsEnabled: false, disableAnimations: false, motionAllowed: false),
        (animationsEnabled: true, disableAnimations: true, motionAllowed: false),
      ];

      for (final scenario in scenarios) {
        _setViewport(tester, const Size(1280, 1200));
        final settings = _FixtureSettingsService(
          _fixtureSettings(
            port: 53318,
            multicastGroup: '224.0.0.168',
            enableAnimations: scenario.animationsEnabled,
          ),
        );
        await tester.pumpWidget(
          _settingsApp(
            settings,
            autoStart: true,
            disableAnimations: scenario.disableAnimations,
            serverState: serverState,
          ),
        );
        await tester.pumpAndSettle();

        final autostartChild = find.text(t.settingsTab.general.launchMinimized);
        final autostartFade = find.ancestor(
          of: autostartChild,
          matching: find.byType(AnimatedOpacity),
        );
        expect(autostartFade, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(autostartFade).duration,
          scenario.motionAllowed ? const Duration(milliseconds: 500) : Duration.zero,
        );

        final warnings = tester.widgetList<M3eMotionAwareCrossFade>(find.byType(M3eMotionAwareCrossFade)).toList();
        expect(warnings, hasLength(3));
        expect(
          warnings.map((warning) => warning.crossFadeState),
          everyElement(CrossFadeState.showSecond),
        );
        expect(
          warnings.map((warning) => warning.motionAllowed),
          everyElement(scenario.motionAllowed),
        );
        final animatedWarnings = tester.widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).toList();
        if (scenario.motionAllowed) {
          expect(animatedWarnings, hasLength(3));
          expect(
            animatedWarnings.map((warning) => warning.duration),
            everyElement(const Duration(milliseconds: 200)),
          );
        } else {
          expect(animatedWarnings, isEmpty);
        }
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'normal-width phone keeps the setting control aligned beside its label',
    (tester) async {
      _setViewport(tester, const Size(390, 1100));
      final settings = _FixtureSettingsService(_fixtureSettings());

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
      final labelColumn = find
          .ancestor(
            of: find.text(t.settingsTab.receive.quickSave),
            matching: find.byType(Column),
          )
          .first;
      final labelColumnRect = tester.getRect(labelColumn);
      final switchRect = tester.getRect(quickSaveSwitch);
      final rowRect = tester.getRect(quickSaveRow);

      expect(switchRect.left, greaterThan(labelColumnRect.right));
      expect(switchRect.center.dy, closeTo(rowRect.center.dy, 0.1));
      expect(
        switchRect.width,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      expect(switchRect.right, lessThanOrEqualTo(390));
      expect(
        find.bySemanticsLabel(
          '${t.settingsTab.receive.quickSave}, ${t.general.off}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'actual localized Settings controls fit 360 and 390dp phone rows',
    (tester) async {
      await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.de));

      for (final screenWidth in [360.0, 390.0]) {
        _setViewport(tester, Size(screenWidth, 1200));
        final settings = _FixtureSettingsService(
          _fixtureSettings(
            advanced: true,
            locale: AppLocale.de,
            deviceModel: 'LocalSend M3 Expressive handset model with a deliberately long device label',
          ),
        );

        await tester.pumpWidget(_settingsApp(settings));
        await tester.pumpAndSettle();

        expect(find.text(t.settingsTab.subtitle), findsOneWidget);
        expect(find.text(t.settingsTab.general.subtitle), findsOneWidget);
        expect(find.text(t.settingsTab.receive.subtitle), findsOneWidget);
        expect(find.text(t.settingsTab.send.subtitle), findsOneWidget);
        expect(find.text(t.settingsTab.network.subtitle), findsOneWidget);
        expect(find.text(t.settingsTab.other.subtitle), findsOneWidget);
        for (final description in [
          t.settingsTab.general.brightnessDescription,
          t.settingsTab.general.colorDescription,
          t.settingsTab.general.languageDescription,
          t.settingsTab.general.animationsDescription,
          t.settingsTab.receive.quickSaveDescription,
          t.settingsTab.receive.quickSaveFromFavoritesDescription,
          t.settingsTab.receive.requirePinDescription,
          t.settingsTab.receive.destinationDescription,
          t.settingsTab.receive.saveToGalleryDescription,
          t.settingsTab.receive.autoFinishDescription,
          t.settingsTab.receive.saveToHistoryDescription,
          t.settingsTab.receive.verifyChecksumsDescription,
          t.settingsTab.send.shareViaLinkAutoAcceptDescription,
          t.settingsTab.send.createChecksumsDescription,
          t.settingsTab.network.serverDescription,
          t.settingsTab.network.aliasDescription,
          t.settingsTab.network.deviceTypeDescription,
          t.settingsTab.network.deviceModelDescription,
          t.settingsTab.network.portDescription,
          t.settingsTab.network.networkDescription,
          t.settingsTab.network.discoveryTimeoutDescription,
          t.settingsTab.network.encryptionDescription,
          t.settingsTab.network.multicastGroupDescription,
          t.settingsTab.other.aboutDescription,
          t.settingsTab.other.supportDescription,
          t.settingsTab.other.privacyPolicyDescription,
          t.settingsTab.advancedSettingsDescription,
        ]) {
          expect(find.text(description), findsOneWidget, reason: '$description is localized and shown');
        }
        for (final label in [
          t.settingsTab.general.brightness,
          t.settingsTab.general.color,
          t.settingsTab.general.language,
          t.settingsTab.general.animations,
          t.settingsTab.receive.quickSave,
          t.settingsTab.receive.quickSaveFromFavorites,
          t.settingsTab.receive.requirePin,
          t.settingsTab.receive.destination,
          t.settingsTab.receive.saveToGallery,
          t.settingsTab.receive.autoFinish,
          t.settingsTab.receive.saveToHistory,
          t.settingsTab.receive.verifyChecksums,
          t.settingsTab.send.shareViaLinkAutoAccept,
          t.settingsTab.send.createChecksums,
          t.settingsTab.network.alias,
          t.settingsTab.network.deviceType,
          t.settingsTab.network.deviceModel,
          t.settingsTab.network.port,
          t.settingsTab.network.network,
          t.settingsTab.network.discoveryTimeout,
          t.settingsTab.network.encryption,
          t.settingsTab.network.multicastGroup,
          t.aboutPage.title,
          t.settingsTab.other.support,
          t.settingsTab.other.privacyPolicy,
          t.settingsTab.advancedSettings,
        ]) {
          final labelFinder = find.text(label);
          expect(labelFinder, findsWidgets, reason: '$label remains discoverable');
          expect(
            find.ancestor(of: labelFinder.last, matching: find.byType(M3eSettingsRow)),
            findsOneWidget,
            reason: '$label remains an individual setting row',
          );
        }

        final brightnessTitle = find.text(t.settingsTab.general.brightness);
        final brightnessRow = find
            .ancestor(
              of: brightnessTitle,
              matching: find.byType(M3eSettingsRow),
            )
            .first;
        final brightnessControl = find.descendant(
          of: brightnessRow,
          matching: find.byType(CustomDropdownButton<ThemeMode>),
        );
        expect(brightnessControl, findsOneWidget);
        final brightnessRect = tester.getRect(brightnessTitle);
        final brightnessSupportRect = tester.getRect(
          find.text(t.settingsTab.general.brightnessDescription),
        );
        final dropdownRect = tester.getRect(brightnessControl);
        final brightnessRowRect = tester.getRect(brightnessRow);
        expect(dropdownRect.right, lessThanOrEqualTo(brightnessRowRect.right));
        expect(dropdownRect.center.dy, greaterThanOrEqualTo(brightnessRect.top));
        expect(dropdownRect.center.dy, lessThanOrEqualTo(brightnessSupportRect.bottom));
        expect(dropdownRect.left, greaterThan(brightnessRect.right));
        expect(dropdownRect.height, greaterThanOrEqualTo(48));

        final brightnessDropdown = tester.widget<DropdownButton<ThemeMode>>(
          find.descendant(
            of: brightnessControl,
            matching: find.byType(DropdownButton<ThemeMode>),
          ),
        );
        expect(brightnessDropdown.onChanged, isNotNull);
        brightnessDropdown.onChanged!(ThemeMode.dark);
        await tester.pumpAndSettle();
        expect(settings.themeUpdates, [ThemeMode.dark]);

        final colorControl = find.byType(CustomDropdownButton<ColorMode>);
        final colorDropdown = tester.widget<DropdownButton<ColorMode>>(
          find.descendant(
            of: colorControl,
            matching: find.byType(DropdownButton<ColorMode>),
          ),
        );
        expect(colorDropdown.onChanged, isNotNull);
        colorDropdown.onChanged!(ColorMode.oled);
        await tester.pumpAndSettle();
        expect(settings.colorModeUpdates, [ColorMode.oled]);
        expect(settings.state.colorMode, ColorMode.oled);
        expect(settings.themeUpdates, [ThemeMode.dark, ThemeMode.dark]);

        for (final (label, description) in [
          (t.settingsTab.network.alias, t.settingsTab.network.aliasDescription),
          (t.settingsTab.network.deviceModel, t.settingsTab.network.deviceModelDescription),
          (t.settingsTab.network.port, t.settingsTab.network.portDescription),
          (
            t.settingsTab.network.discoveryTimeout,
            t.settingsTab.network.discoveryTimeoutDescription,
          ),
        ]) {
          final labelFinder = find.text(label).first;
          final row = find.ancestor(of: labelFinder, matching: find.byType(M3eSettingsRow)).first;
          final control = label == t.settingsTab.network.alias
              ? find.descendant(of: row, matching: find.byType(TextButton)).first
              : find.descendant(of: row, matching: find.byType(TextField)).first;
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();

          final title = find
              .descendant(
                of: row,
                matching: find.text(label),
              )
              .first;
          final titleParagraph = tester.renderObject<RenderParagraph>(title);
          final titleRect = tester.getRect(title);
          final supportingTextRect = tester.getRect(
            find.descendant(of: row, matching: find.text(description)).first,
          );
          final fieldRect = tester.getRect(control);
          final rowRect = tester.getRect(row);
          expect(titleParagraph.constraints.maxWidth, greaterThanOrEqualTo(96));
          expect(fieldRect.left, greaterThan(titleRect.right));
          expect(fieldRect.center.dy, greaterThanOrEqualTo(titleRect.top));
          expect(fieldRect.center.dy, lessThanOrEqualTo(supportingTextRect.bottom));
          expect(fieldRect.right, lessThanOrEqualTo(rowRect.right));
          expect(tester.takeException(), isNull);
        }
      }

      LocaleSettings.setLocaleSync(AppLocale.en);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'desktop preferences keep descriptions and spacious text controls',
    (tester) async {
      _setViewport(tester, const Size(900, 1200));
      final settings = _FixtureSettingsService(
        _fixtureSettings(advanced: true),
      );

      await tester.pumpWidget(_settingsApp(settings, autoStart: true));
      await tester.pumpAndSettle();

      for (final (title, description) in [
        (
          t.settingsTab.general.saveWindowPlacementWindows,
          t.settingsTab.general.saveWindowPlacementDescription,
        ),
        (
          t.settingsTab.general.minimizeToTray,
          t.settingsTab.general.minimizeToTrayDescription,
        ),
        (
          t.settingsTab.general.launchAtStartup,
          t.settingsTab.general.launchAtStartupDescription,
        ),
        (
          t.settingsTab.general.launchMinimized,
          t.settingsTab.general.launchMinimizedDescription,
        ),
        (
          t.settingsTab.general.showInContextMenu,
          t.settingsTab.general.showInContextMenuDescription,
        ),
      ]) {
        expect(find.text(title), findsOneWidget, reason: '$title remains an individual option');
        expect(find.text(description), findsOneWidget, reason: '$title keeps its explanation');
      }

      final aliasRow = find
          .ancestor(
            of: find.text(t.settingsTab.network.alias),
            matching: find.byType(M3eSettingsRow),
          )
          .first;
      await tester.ensureVisible(aliasRow);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(
              find.descendant(of: aliasRow, matching: find.byType(TextButton)).first,
            )
            .width,
        greaterThan(132),
      );

      for (final label in [
        t.settingsTab.network.deviceModel,
        t.settingsTab.network.multicastGroup,
      ]) {
        final row = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(M3eSettingsRow),
            )
            .first;
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(
                find.descendant(of: row, matching: find.byType(TextField)).first,
              )
              .width,
          greaterThan(132),
          reason: '$label remains comfortably editable on desktop',
        );
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'quick-save row keeps its semantic state and persistence callback',
    (tester) async {
      _setViewport(tester, const Size(390, 900));
      final settings = _FixtureSettingsService(
        _fixtureSettings(quickSave: true),
      );
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
        expect(
          find.bySemanticsLabel(
            '${t.settingsTab.receive.quickSave}, ${t.general.on}',
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(quickSaveSwitch);
        await tester.tap(quickSaveSwitch);
        await tester.pumpAndSettle();

        expect(settings.quickSaveUpdates, [false]);
        expect(settings.quickSaveFromFavoritesUpdates, isEmpty);
        expect(settings.state.quickSave, isFalse);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.bySemanticsLabel(
            '${t.settingsTab.receive.quickSave}, ${t.general.off}',
          ),
          findsOneWidget,
        );
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
      final settings = _FixtureSettingsService(
        _fixtureSettings(quickSave: true),
      );

      await tester.pumpWidget(_settingsApp(settings));
      await tester.pumpAndSettle();
      expect(
        t.settingsTab.receive.quickSaveFromFavoritesDescription,
        'Automatically accept and save incoming files from your favorite devices',
      );
      expect(
        find.text(t.settingsTab.receive.quickSaveFromFavoritesDescription),
        findsOneWidget,
      );
      await tester.ensureVisible(
        _switchInRow(t.settingsTab.receive.quickSaveFromFavorites),
      );
      await tester.tap(
        _switchInRow(t.settingsTab.receive.quickSaveFromFavorites),
      );
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

Widget _settingsApp(
  _FixtureSettingsService settings, {
  double textScale = 1,
  bool autoStart = false,
  bool disableAnimations = false,
  ServerState? serverState,
}) {
  final deviceInfo = DeviceInfoResult(
    deviceType: DeviceType.desktop,
    deviceModel: null,
    androidSdkInt: null,
  );
  final parentState = _parentState(settings.initialSettings, deviceInfo);

  return RefenaScope(
    key: UniqueKey(),
    overrides: [
      settingsProvider.overrideWithNotifier((_) => settings),
      parentIsolateProvider.overrideWithNotifier(
        (_) => IsolateController(initialState: parentState),
      ),
      settingsTabControllerProvider.overrideWithNotifier((ref) {
        final settingsService = ref.notifier(settingsProvider);
        return _FixtureSettingsTabController(
          settingsService: settingsService,
          deviceInfo: deviceInfo,
          autoStart: autoStart,
          serverState: serverState,
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
            data:
                MediaQuery.of(
                  context,
                ).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: disableAnimations,
                ),
            child: const SettingsTab(),
          ),
        ),
      ),
    ),
  );
}

ParentIsolateState _parentState(
  SettingsState settings,
  DeviceInfoResult deviceInfo,
) {
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

SettingsState _fixtureSettings({
  bool quickSave = false,
  bool quickSaveFromFavorites = false,
  bool advanced = false,
  AppLocale locale = AppLocale.en,
  String? deviceModel,
  int port = 53317,
  String multicastGroup = '224.0.0.167',
  bool enableAnimations = true,
}) {
  return SettingsState(
    showToken: '',
    alias: 'LocalSend test device',
    theme: ThemeMode.system,
    colorMode: ColorMode.system,
    customColor: const Color(0xFF000000),
    locale: locale,
    port: port,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: multicastGroup,
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
    enableAnimations: enableAnimations,
    deviceType: DeviceType.desktop,
    deviceModel: deviceModel,
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: false,
    verifyChecksums: false,
    discoveryTimeout: 5,
    advancedSettings: advanced,
  );
}

class _FixtureSettingsService extends SettingsService {
  final SettingsState initialSettings;
  final List<ThemeMode> themeUpdates = [];
  final List<ColorMode> colorModeUpdates = [];
  final List<bool> quickSaveUpdates = [];
  final List<bool> quickSaveFromFavoritesUpdates = [];

  _FixtureSettingsService(this.initialSettings) : super(MockPersistenceService());

  @override
  SettingsState init() => initialSettings;

  @override
  Future<void> setTheme(ThemeMode theme) async {
    themeUpdates.add(theme);
    state = state.copyWith(theme: theme);
  }

  @override
  Future<void> setColorMode(ColorMode mode) async {
    colorModeUpdates.add(mode);
    state = state.copyWith(colorMode: mode);
  }

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
  final bool _autoStart;
  final ServerState? _serverState;

  _FixtureSettingsTabController({
    required super.settingsService,
    required DeviceInfoResult deviceInfo,
    bool autoStart = false,
    ServerState? serverState,
  }) : _settingsService = settingsService,
       _deviceInfo = deviceInfo,
       _autoStart = autoStart,
       _serverState = serverState,
       super(
         serverNotifier: ServerService(),
         isolateController: IsolateController(
           initialState: _parentState(settingsService.state, deviceInfo),
         ),
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
      deviceModelController: TextEditingController(
        text: settings.deviceModel ?? '',
      ),
      portController: TextEditingController(text: settings.port.toString()),
      timeoutController: TextEditingController(
        text: settings.discoveryTimeout.toString(),
      ),
      multicastController: TextEditingController(text: settings.multicastGroup),
      settings: settings,
      serverState: _serverState,
      deviceInfo: _deviceInfo,
      colorModes: ColorMode.values,
      autoStart: _autoStart,
      autoStartLaunchHidden: false,
      showInContextMenu: false,
      onChangeTheme: (_, theme) async {
        await _settingsService.setTheme(theme);
      },
      onChangeColorMode: (_, colorMode) async {
        await _settingsService.setColorMode(colorMode);
        if (colorMode == ColorMode.oled) {
          await _settingsService.setTheme(ThemeMode.dark);
        }
      },
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
