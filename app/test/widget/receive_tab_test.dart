import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/network_state.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/m3e/m3e_background.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets(
    'Receive link CTA stays tappable above production floating navigation at narrow sizes',
    (tester) async {
      for (final height in [460.0, 760.0, 1100.0]) {
        _setViewport(tester, Size(320, height));
        final navigationService = _RecordingNavigationService();
        await tester.pumpWidget(
          _receiveApp(
            textScale: 1.8,
            animationsEnabled: false,
            navigationService: navigationService,
          ),
        );
        await tester.pumpAndSettle();

        final alias = find.text('Test receiver');
        expect(find.text('LocalSend'), findsOneWidget);
        expect(find.text(t.receiveTab.subtitle), findsOneWidget);
        final link = find.text(t.receiveTab.link);
        expect(alias, findsOneWidget);
        expect(link, findsOneWidget);
        await tester.ensureVisible(alias);
        await tester.pumpAndSettle();
        var rect = tester.getRect(alias);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(height));

        final cta = find.byType(M3eTonalActionButton);
        expect(cta, findsOneWidget);
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        rect = tester.getRect(cta);
        final navigationRect = tester.getRect(
          find.byType(M3eFloatingNavigationBar),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.width, lessThanOrEqualTo(320 * 0.56));
        expect(rect.height, greaterThanOrEqualTo(64));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(height));
        expect(rect.bottom, lessThanOrEqualTo(navigationRect.top));
        expect(rect.overlaps(navigationRect), isFalse);

        await tester.tapAt(rect.center);
        await tester.pump();
        expect(navigationService.pushedWidget, isA<WebSharePage>());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Receive link CTA remains viewport-relative on phone, tablet, and desktop screens',
    (tester) async {
      for (final viewport in [
        const Size(390, 900),
        const Size(1000, 900),
        const Size(1920, 1080),
      ]) {
        _setViewport(tester, viewport);
        final navigationService = _RecordingNavigationService();
        await tester.pumpWidget(
          _receiveApp(
            animationsEnabled: false,
            navigationService: navigationService,
          ),
        );
        await tester.pumpAndSettle();

        final cta = find.byType(M3eTonalActionButton);
        final rect = tester.getRect(cta);
        expect(
          rect.width,
          inInclusiveRange(viewport.width * 0.54, viewport.width * 0.56),
        );
        expect(rect.center.dx, closeTo(viewport.width / 2, 0.1));
        expect(rect.height, greaterThanOrEqualTo(64));
        await tester.tapAt(rect.center);
        await tester.pump();
        expect(navigationService.pushedWidget, isA<WebSharePage>());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Receive logo rotation respects both the saved app setting and system reduced motion',
    (tester) async {
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];
      const activeServer = ServerState(
        alias: 'Test receiver',
        port: 53317,
        https: false,
        session: null,
        webSendState: null,
        webUpload: false,
        webPin: null,
      );

      for (final (animationsEnabled, disableAnimations, shouldSpin) in scenarios) {
        await tester.pumpWidget(
          _receiveApp(
            serverState: activeServer,
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        final rotatingLogo = tester.widget<RotatingWidget>(
          find.byType(RotatingWidget),
        );
        expect(rotatingLogo.spinning, shouldSpin);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 600));
      }
    },
  );

  testWidgets(
    'Receive offline fade respects saved and system reduced motion',
    (tester) async {
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      for (final (animationsEnabled, disableAnimations, shouldAnimate) in scenarios) {
        _setViewport(tester, const Size(390, 900));
        await tester.pumpWidget(
          _receiveApp(
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );

        final offline = find.text(t.general.offline);
        final fade = find.ancestor(
          of: offline,
          matching: find.byType(AnimatedOpacity),
        );
        final fadeTransition = find.descendant(
          of: fade,
          matching: find.byType(FadeTransition),
        );
        expect(fade, findsOneWidget);
        await tester.pump();
        expect(
          tester.widget<AnimatedOpacity>(fade).duration,
          shouldAnimate ? const Duration(milliseconds: 300) : Duration.zero,
        );

        if (shouldAnimate) {
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 100));
          final opacity = tester.widget<FadeTransition>(fadeTransition).opacity.value;
          expect(opacity, greaterThan(0));
          expect(opacity, lessThan(1));
        } else {
          await tester.pumpAndSettle();
          expect(tester.widget<FadeTransition>(fadeTransition).opacity.value, 1);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Receive info and History transitions respect saved and system reduced motion',
    (tester) async {
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      for (final (animationsEnabled, disableAnimations, shouldAnimate) in scenarios) {
        await tester.pumpWidget(
          _receiveApp(
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        final infoButton = find.byKey(const ValueKey('info-btn'));
        final historyButton = find.byTooltip(t.receiveHistoryPage.title);
        final infoTransition = find.byType(M3eMotionAwareCrossFade);
        final infoBoxAlias = find.text(t.receiveTab.infoBox.alias);
        final expectedDuration = shouldAnimate ? const Duration(milliseconds: 200) : Duration.zero;
        expect(historyButton, findsOneWidget);
        expect(infoTransition, findsOneWidget);
        expect(
          tester.widget<M3eMotionAwareCrossFade>(infoTransition).motionAllowed,
          shouldAnimate,
        );
        expect(
          tester.widget<M3eMotionAwareCrossFade>(infoTransition).crossFadeState,
          CrossFadeState.showFirst,
        );
        if (shouldAnimate) {
          expect(find.byType(AnimatedCrossFade), findsOneWidget);
          expect(
            tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).duration,
            expectedDuration,
          );
        } else {
          expect(find.byType(AnimatedCrossFade), findsNothing);
          expect(infoBoxAlias, findsNothing);
        }

        await tester.tap(infoButton);
        await tester.pump();
        expect(
          tester.widget<M3eMotionAwareCrossFade>(infoTransition).crossFadeState,
          CrossFadeState.showSecond,
        );
        if (shouldAnimate) {
          expect(
            tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).duration,
            expectedDuration,
          );
        } else {
          expect(find.byType(AnimatedCrossFade), findsNothing);
          expect(infoBoxAlias, findsOneWidget);
        }
        expect(historyButton, findsNothing);

        await tester.tap(infoButton);
        await tester.pump();
        expect(
          tester.widget<M3eMotionAwareCrossFade>(infoTransition).crossFadeState,
          CrossFadeState.showFirst,
        );
        if (!shouldAnimate) {
          expect(find.byType(AnimatedCrossFade), findsNothing);
          expect(infoBoxAlias, findsNothing);
        }
        expect(historyButton, findsOneWidget);
        final historyFade = find.ancestor(
          of: historyButton,
          matching: find.byType(AnimatedOpacity),
        );
        expect(historyFade, findsOneWidget);
        expect(
          tester.widget<AnimatedOpacity>(historyFade).duration,
          expectedDuration,
        );

        if (shouldAnimate) {
          expect(tester.widget<AnimatedOpacity>(historyFade).opacity, 0);
          await tester.pump(const Duration(milliseconds: 199));
          expect(tester.widget<AnimatedOpacity>(historyFade).opacity, 0);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.widget<AnimatedOpacity>(historyFade).opacity, 1);
        } else {
          expect(tester.widget<AnimatedOpacity>(historyFade).opacity, 1);
          await tester.pump();
          expect(tester.widget<AnimatedOpacity>(historyFade).opacity, 1);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _receiveApp({
  ServerState? serverState,
  bool animationsEnabled = false,
  bool disableAnimations = false,
  double textScale = 1,
  NavigationService? navigationService,
}) {
  final settings = _FixtureSettingsService();
  return RefenaScope(
    key: UniqueKey(),
    overrides: [
      settingsProvider.overrideWithNotifier((_) => settings),
      serverProvider.overrideWithNotifier(
        (_) => _FixtureServerService(serverState),
      ),
      localIpProvider.overrideWithNotifier(
        (_) => _FixtureLocalIpService(settings),
      ),
      animationProvider.overrideWithBuilder((_) => animationsEnabled),
      navigationProvider.overrideWithValue(
        navigationService ?? _RecordingNavigationService(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
      home: const _ReceiveMobileShell(),
    ),
  );
}

class _ReceiveMobileShell extends StatelessWidget {
  const _ReceiveMobileShell();

  @override
  Widget build(BuildContext context) {
    return M3eExpressiveBackground(
      emphasis: M3eBackgroundEmphasis.receive,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          left: true,
          child: PageView(
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ReceiveTab(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
          ),
        ),
        bottomNavigationBar: M3eFloatingNavigationBar(
          selectedIndex: 0,
          animationsEnabled: context.ref.watch(animationProvider),
          destinations: [
            M3eNavigationDestination(
              icon: Icons.download_for_offline_outlined,
              label: t.receiveTab.title,
              onTap: () {},
            ),
            M3eNavigationDestination(
              icon: Icons.send,
              label: t.sendTab.title,
              onTap: () {},
            ),
            M3eNavigationDestination(
              icon: Icons.settings,
              label: t.settingsTab.title,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingNavigationService extends NavigationService {
  Widget? pushedWidget;

  @override
  Future<T?> push<T>(Widget widget, {NavigationTransition? transition}) async {
    pushedWidget = widget;
    return null;
  }
}

class _FixtureSettingsService extends SettingsService {
  _FixtureSettingsService() : super(MockPersistenceService());

  @override
  SettingsState init() => const SettingsState(
    showToken: '',
    alias: 'Test receiver',
    theme: ThemeMode.system,
    colorMode: ColorMode.system,
    customColor: Colors.black,
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

class _FixtureLocalIpService extends LocalIpService {
  _FixtureLocalIpService(super.settingsService);

  @override
  NetworkState init() => const NetworkState(localIps: [], initialized: true);

  @override
  get initialAction => null;
}

class _FixtureServerService extends ServerService {
  final ServerState? _serverState;

  _FixtureServerService(this._serverState);

  @override
  ServerState? init() => _serverState;
}
