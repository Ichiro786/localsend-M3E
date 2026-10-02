import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/persistence/receive_history_entry.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/home_tab.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/favorites_provider.dart';
import 'package:localsend_app/provider/logging/discovery_logs_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/list_tile/device_placeholder_list_tile.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:localsend_isolates/model/dto/multicast_dto.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets(
    'Send concept header keeps History and Settings shortcuts actionable',
    (tester) async {
      final device = _fixtureDevice();
      _setViewport(tester, const Size(390, 1100));
      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, [])),
      );
      await tester.pumpAndSettle();

      expect(find.text(t.sendTab.title), findsOneWidget);
      expect(find.text(t.sendTab.subtitle), findsOneWidget);
      expect(find.text(t.sendTab.selection.title), findsNothing);
      expect(
        find.text(t.sendTab.devicesAvailable(count: 1)),
        findsOneWidget,
      );
      expect(find.text(t.sendTab.platforms.desktop), findsOneWidget);
      expect(find.text('Same Wi-Fi'), findsNothing);
      final historyButton = find.ancestor(
        of: find.byTooltip(t.receiveHistoryPage.title),
        matching: find.byType(IconButton),
      );
      final settingsButton = find.ancestor(
        of: find.byTooltip(t.settingsTab.title),
        matching: find.byType(IconButton),
      );
      final history = tester.widget<IconButton>(
        historyButton,
      );
      final settings = tester.widget<IconButton>(
        settingsButton,
      );
      expect(history.onPressed, isNotNull);
      expect(settings.onPressed, isNotNull);

      final sendContext = tester.element(find.byType(_SendTestShell));
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      expect(
        sendContext.ref.read(homePageControllerProvider).currentTab,
        HomeTab.settings,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Send History shortcut opens the existing ReceiveHistoryPage destination',
    (tester) async {
      final originalNavigatorKey = Routerino.navigatorKey;
      final navigatorKey = GlobalKey<NavigatorState>();
      Routerino.navigatorKey = navigatorKey;
      addTearDown(() => Routerino.navigatorKey = originalNavigatorKey);

      final device = _fixtureDevice();
      _setViewport(tester, const Size(390, 1100));
      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, []),
          navigatorKey: navigatorKey,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(t.receiveHistoryPage.title));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiveHistoryPage), findsOneWidget);
      expect(find.text(t.receiveHistoryPage.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Send Settings navigation respects saved and system reduced motion',
    (tester) async {
      const scenarios = [
        (false, false, false),
        (true, true, false),
        (true, false, true),
      ];
      addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

      for (final (animationsEnabled, disableAnimations, shouldAnimate) in scenarios) {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
          disableAnimations: disableAnimations,
        );
        _setViewport(tester, const Size(390, 1100));
        final device = _fixtureDevice();
        await tester.pumpWidget(
          _sendApp(
            device: device,
            vm: _fixtureVm(device, []),
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        await tester.pumpAndSettle();

        final sendContext = tester.element(find.byType(_SendTestShell));
        final controller = sendContext.ref.read(homePageControllerProvider).controller;
        final settingsButton = find.ancestor(
          of: find.byTooltip(t.settingsTab.title),
          matching: find.byType(IconButton),
        );
        await tester.tap(settingsButton);
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          sendContext.ref.read(homePageControllerProvider).currentTab,
          HomeTab.settings,
        );
        expect(controller.page, isNotNull);
        if (shouldAnimate) {
          expect(controller.position.isScrollingNotifier.value, isTrue);
          expect(controller.page!, lessThan(2));
        } else {
          expect(controller.page!, closeTo(2, 0.01));
        }

        await tester.pumpAndSettle();
        expect(controller.page!, closeTo(2, 0.01));
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'file picker tile dispatches the existing file option action',
    (tester) async {
      const pickerChannel = MethodChannel('org.localsend.localsend_app/localsend');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(pickerChannel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(pickerChannel, null));
      final originalNavigatorKey = Routerino.navigatorKey;
      final navigatorKey = GlobalKey<NavigatorState>();
      Routerino.navigatorKey = navigatorKey;
      addTearDown(() => Routerino.navigatorKey = originalNavigatorKey);

      final device = _fixtureDevice();
      final observer = RefenaHistoryObserver.only(actionDispatched: true);
      _setViewport(tester, const Size(390, 1100));
      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, []),
          observers: [observer],
          navigatorKey: navigatorKey,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(M3eSelectionCard).first);
      await tester.pumpAndSettle();

      final pickerActions = observer.dispatchedActions.whereType<PickFileAction>().toList();
      expect(pickerActions, hasLength(1));
      expect(pickerActions.single.option, FilePickerOption.file);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'all Send picker cards forward their exact picker option',
    (tester) async {
      final device = _fixtureDevice();
      final selectedOptions = <FilePickerOption>[];
      _setViewport(tester, const Size(390, 1100));
      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, []),
          onPickerOption: (option) async => selectedOptions.add(option),
        ),
      );
      await tester.pumpAndSettle();

      expect(pickerOptions, hasLength(6));
      expect(find.byType(M3eSelectionCard), findsNWidgets(6));
      for (var index = 0; index < pickerOptions.length; index++) {
        await tester.tap(find.byType(M3eSelectionCard).at(index));
        await tester.pumpAndSettle();
      }

      expect(selectedOptions, pickerOptions);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('selected-file Edit and Add actions meet 48dp targets at 320dp', (tester) async {
    final device = _fixtureDevice();
    final theme = ThemeData(
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFE8EEEC),
      ),
    );
    const selectedFile = CrossFile(
      name: 'notes.txt',
      fileType: FileType.text,
      size: 5,
      thumbnail: null,
      asset: null,
      path: null,
      bytes: null,
      lastModified: null,
      lastAccessed: null,
    );
    _setViewport(tester, const Size(320, 1000));

    await tester.pumpWidget(
      _sendApp(
        device: device,
        vm: _fixtureVm(device, [], selectedFiles: [selectedFile]),
        theme: theme,
      ),
    );
    await tester.pumpAndSettle();

    final edit = tester.getRect(
      find.ancestor(
        of: find.text(t.general.edit),
        matching: find.byType(TextButton),
      ),
    );
    final add = tester.getRect(
      find.ancestor(
        of: find.text(t.general.add),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(edit.height, greaterThanOrEqualTo(48));
    expect(add.height, greaterThanOrEqualTo(48));
    expect(edit.left, greaterThanOrEqualTo(0));
    expect(add.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'Send mode remains actionable when files are selected',
    (tester) async {
      final device = _fixtureDevice();
      final selectedModes = <SendMode>[];
      const selectedFile = CrossFile(
        name: 'notes.txt',
        fileType: FileType.text,
        size: 5,
        thumbnail: null,
        asset: null,
        path: null,
        bytes: null,
        lastModified: null,
        lastAccessed: null,
      );
      final theme = ThemeData(
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFE8EEEC),
        ),
      );
      _setViewport(tester, const Size(390, 1100));

      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, [], selectedModes: selectedModes, selectedFiles: [selectedFile]),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final modeButton = find.byTooltip(t.sendTab.sendMode);
      expect(modeButton, findsOneWidget);
      await tester.tap(modeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sendTab.sendModes.link));
      await tester.pumpAndSettle();

      expect(selectedModes, [SendMode.link]);
      expect(find.byTooltip(t.sendTab.sendMode), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'normal-width phone shows a compact 3 by 2 picker and nearby actions above the navigation reserve',
    (tester) async {
      final device = _fixtureDevice();
      _setViewport(tester, const Size(390, 1100));

      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, [])),
      );
      await tester.pumpAndSettle();

      final cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects.take(3).map((rect) => rect.top).toSet().length, 1);
      expect(cardRects[3].top, greaterThan(cardRects[0].bottom));
      for (final rect in cardRects) {
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }

      final nearby = tester.getRect(find.text(t.sendTab.nearbyDevices));
      expect(nearby.top, greaterThan(cardRects[3].bottom));
      for (final tooltip in [
        t.sendTab.scan,
        t.sendTab.manualSending,
        t.dialogs.favoriteDialog.title,
      ]) {
        final action = tester.getRect(find.byTooltip(tooltip));
        expect(action.width, greaterThanOrEqualTo(48));
        expect(action.height, greaterThanOrEqualTo(48));
        expect(
          action.bottom,
          lessThan(1004),
          reason: '$tooltip should remain above the floating-navigation reserve',
        );
      }
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'six picker choices share one uniform icon accent treatment',
    (tester) async {
      final device = _fixtureDevice();
      _setViewport(tester, const Size(390, 1100));
      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, [])),
      );
      await tester.pumpAndSettle();

      final cards = tester.widgetList<M3eSelectionCard>(
        find.byType(M3eSelectionCard),
      );
      expect(cards, hasLength(6));
      expect(
        cards.map((card) => card.accent),
        List.filled(6, M3eSelectionAccent.primaryFixed),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'picker grid uses three columns on a normal phone and two below 320 dp of content width',
    (tester) async {
      final device = _fixtureDevice();
      final calls = <String>[];

      _setViewport(tester, const Size(351, 1000));
      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, calls)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(M3eSelectionCard),
        findsNWidgets(pickerOptions.length),
      );
      var cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects[1].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[2].top, greaterThan(cardRects[0].bottom));
      expect(cardRects.first.height, 112);
      expect(tester.takeException(), isNull);

      _setViewport(tester, const Size(352, 1000));
      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, calls)),
      );
      await tester.pumpAndSettle();

      cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects[1].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[2].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[3].top, greaterThan(cardRects[0].bottom));
      expect(tester.takeException(), isNull);

      _setViewport(tester, const Size(360, 1000));
      await tester.pumpWidget(
        _sendApp(device: device, vm: _fixtureVm(device, calls)),
      );
      await tester.pumpAndSettle();
      cardRects = [
        for (var index = 0; index < pickerOptions.length; index++) tester.getRect(find.byType(M3eSelectionCard).at(index)),
      ];
      expect(cardRects[1].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[2].top, closeTo(cardRects[0].top, 0.1));
      expect(cardRects[3].top, greaterThan(cardRects[0].bottom));
      expect(cardRects.first.width, greaterThanOrEqualTo(96));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Send peer heading and selected/troubleshooting cards use shared styles and shape token',
    (tester) async {
      final device = _fixtureDevice();
      final theme = ThemeData(
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFE8EEEC),
        ),
      );
      final selectedFile = const CrossFile(
        name: 'notes.txt',
        fileType: FileType.text,
        size: 5,
        thumbnail: null,
        asset: null,
        path: null,
        bytes: null,
        lastModified: null,
        lastAccessed: null,
      );
      _setViewport(tester, const Size(390, 1100));

      await tester.pumpWidget(
        _sendApp(
          device: device,
          vm: _fixtureVm(device, [], selectedFiles: [selectedFile]),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final nearbyHeading = tester.widget<Text>(
        find.text(t.sendTab.nearbyDevices),
      );
      final resolvedTheme = Theme.of(tester.element(find.byType(SendTab)));
      expect(
        nearbyHeading.style?.fontSize,
        resolvedTheme.textTheme.titleLarge?.fontSize,
      );
      expect(nearbyHeading.style?.fontWeight, FontWeight.w600);

      final selectedCard = find.ancestor(
        of: find.text(t.sendTab.selection.title),
        matching: find.byType(Card),
      );
      final troubleshootingCard = find.ancestor(
        of: find.text(t.troubleshootPage.title).last,
        matching: find.byType(Card),
      );
      for (final cardFinder in [selectedCard, troubleshootingCard]) {
        final shape = tester.widget<Card>(cardFinder).shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(M3eTokens.cardRadius));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'troubleshooting slideshow respects both saved and system reduced-motion settings',
    (tester) async {
      final device = _fixtureDevice();
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      for (final (animationsEnabled, disableAnimations, shouldRun) in scenarios) {
        await tester.pumpWidget(
          _sendApp(
            device: device,
            vm: _fixtureVm(device, []),
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        final slideshow = tester.widget<OpacitySlideshow>(
          find.byType(OpacitySlideshow),
        );
        expect(
          slideshow.running,
          shouldRun,
          reason: 'app animations=$animationsEnabled, system reduced motion=$disableAnimations',
        );
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'scan and per-IP sync rotations respect app and system reduced motion',
    (tester) async {
      final device = _fixtureDevice();
      final localIps = List.generate(
        StartSmartScan.maxInterfaces + 1,
        (index) => '192.168.1.${index + 10}',
      );
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      _setViewport(tester, const Size(390, 1100));
      for (final (animationsEnabled, disableAnimations, shouldSpin) in scenarios) {
        await tester.pumpWidget(
          _sendApp(
            device: device,
            vm: _fixtureVm(device, [], localIps: localIps),
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
            runningIps: {localIps.first},
          ),
        );
        await tester.pump();

        final scanButton = find.byTooltip(t.sendTab.scan);
        expect(scanButton, findsOneWidget);
        final scanRotator = find.ancestor(
          of: find.byIcon(Icons.sync).first,
          matching: find.byType(RotatingWidget),
        );
        expect(
          tester.widget<RotatingWidget>(scanRotator.first).spinning,
          shouldSpin,
        );
        final scanIcon = find.byIcon(Icons.sync).first;
        final scanIconColor = tester.widget<Icon>(scanIcon).color;
        final warningColor = Theme.of(
          tester.element(scanIcon),
        ).colorScheme.warning;
        if (shouldSpin) {
          expect(scanIconColor, isNull);
        } else {
          expect(scanIconColor, warningColor);
        }
        final scanTransform = find.descendant(
          of: scanRotator.first,
          matching: find.byType(Transform),
        );
        final scanBefore = _rotationMatrix(tester, scanTransform);

        await tester.tap(scanButton);
        await tester.pump(const Duration(milliseconds: 500));
        final scanAfter = _rotationMatrix(tester, scanTransform);
        if (shouldSpin) {
          expect(scanAfter, isNot(equals(scanBefore)));
        } else {
          expect(scanAfter, equals(scanBefore));
        }
        final ipMenuItem = find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String> && widget.value == localIps.first,
        );
        expect(ipMenuItem, findsOneWidget);
        final ipRotator = find.descendant(
          of: ipMenuItem,
          matching: find.byType(RotatingWidget),
        );
        expect(ipRotator, findsOneWidget);
        expect(tester.widget<RotatingWidget>(ipRotator).spinning, shouldSpin);

        final transform = find.descendant(
          of: ipRotator,
          matching: find.byType(Transform),
        );
        final before = _rotationMatrix(tester, transform);
        await tester.pump(const Duration(milliseconds: 300));
        final after = _rotationMatrix(tester, transform);
        if (shouldSpin) {
          expect(after, isNot(equals(before)));
        } else {
          expect(after, equals(before));
        }
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'discovery placeholder slideshow respects saved and system reduced motion',
    (tester) async {
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      for (final (animationsEnabled, disableAnimations, shouldRun) in scenarios) {
        await tester.pumpWidget(
          _placeholderApp(
            animationsEnabled: animationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        final slideshowFinder = find.byType(OpacitySlideshow);
        final slideshow = tester.widget<OpacitySlideshow>(slideshowFinder);
        expect(slideshow.running, shouldRun);
        final iconFinder = find.descendant(
          of: slideshowFinder,
          matching: find.byType(Icon),
        );
        final before = tester.widget<Icon>(iconFinder.first).icon;

        await tester.pump(const Duration(milliseconds: 3500));
        final after = tester.widget<Icon>(iconFinder.first).icon;
        if (shouldRun) {
          expect(after, isNot(before));
        } else {
          expect(after, before);
        }
        expect(tester.takeException(), isNull);
      }
    },
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

      expect(
        find.byType(M3eSelectionCard),
        findsNWidgets(pickerOptions.length),
      );
      for (final card in find.byType(M3eSelectionCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.height, greaterThanOrEqualTo(124.6));
        expect(rect.height, lessThan(180));
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
        _sendApp(device: device, vm: _fixtureVm(device, []), textScale: 2),
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
      final card = find.ancestor(
        of: title,
        matching: find.byType(M3eSelectionCard),
      );
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
        expect(
          find.bySemanticsLabel(t.dialogs.favoriteDialog.title),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(t.sendTab.sendMode), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel(t.sendTab.manualSending)),
          matchesSemantics(
            label: t.sendTab.manualSending,
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(t.dialogs.favoriteDialog.title),
          ),
          matchesSemantics(
            label: t.dialogs.favoriteDialog.title,
            isButton: true,
            hasTapAction: true,
          ),
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
    'device protocol badges reflect advertised HTTP, HTTPS and signaling channels',
    (tester) async {
      _setViewport(tester, const Size(390, 1100));
      final scenarios = [
        (device: _fixtureDevice(ip: null), label: 'HTTP', hidden: 'HTTPS'),
        (device: _fixtureDevice(https: true), label: 'HTTPS', hidden: 'HTTP'),
        (
          device: _fixtureDevice(ip: null, includeHttp: false, includeWebRtc: true),
          label: 'WebRTC',
          hidden: 'HTTP',
        ),
      ];

      for (final scenario in scenarios) {
        await tester.pumpWidget(
          _sendApp(
            device: scenario.device,
            vm: _fixtureVm(scenario.device, []),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(scenario.label), findsOneWidget);
        expect(find.text(scenario.hidden), findsNothing);
        expect(tester.takeException(), isNull);
      }

      final ipOnly = _fixtureDevice(includeHttp: false);
      await tester.pumpWidget(
        _sendApp(device: ipOnly, vm: _fixtureVm(ipOnly, [])),
      );
      await tester.pumpAndSettle();
      expect(find.text('HTTP'), findsNothing);
      expect(find.text('HTTPS'), findsNothing);
      expect(find.text('WebRTC'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'channel-less local device row retains its explicit HTTP or HTTPS summary badge',
    (tester) async {
      _setViewport(tester, const Size(390, 400));

      for (final https in [false, true]) {
        final localDevice = _fixtureDevice(
          https: https,
          includeHttp: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: DeviceListTile(
                  device: localDevice,
                  showLocalProtocolBadge: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final label = https ? 'HTTPS' : 'HTTP';
        final hiddenLabel = https ? 'HTTP' : 'HTTPS';
        expect(find.text(label), findsOneWidget);
        expect(find.text(hiddenLabel), findsNothing);
        expect(tester.takeException(), isNull);
      }

      for (final unavailableDevice in [
        _fixtureDevice(https: true, ip: '-', port: -1, includeHttp: false),
        _fixtureDevice(https: true, ip: null, includeHttp: false),
        _fixtureDevice(https: true, port: -1, includeHttp: false),
        _fixtureDevice(https: true, ip: '  ', includeHttp: false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: DeviceListTile(
                device: unavailableDevice,
                showLocalProtocolBadge: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('HTTPS'), findsNothing);
        expect(find.text('HTTP'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'picker and troubleshooting surfaces use the active light, dark, and OLED-compatible schemes',
    (tester) async {
      final device = _fixtureDevice();
      final schemes = [
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
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
          _sendApp(device: device, vm: _fixtureVm(device, []), theme: theme),
        );
        await tester.pumpAndSettle();

        final selection = find.byType(M3eSelectionCard).first;
        final card = tester.widget<Card>(
          find.descendant(of: selection, matching: find.byType(Card)),
        );
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
        expect(
          (iconSurface.decoration as BoxDecoration).color,
          scheme.primaryContainer,
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: selection, matching: find.byType(Icon)).first,
              )
              .color,
          scheme.onPrimaryContainer,
        );

        final troubleshoot = find.ancestor(
          of: find.text(t.troubleshootPage.title).last,
          matching: find.byType(Card),
        );
        expect(
          tester.widget<Card>(troubleshoot).color,
          scheme.surfaceContainerLow.withValues(alpha: 0.62),
        );
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

List<double> _rotationMatrix(WidgetTester tester, Finder transform) {
  return tester.widget<Transform>(transform).transform.storage.toList();
}

Widget _placeholderApp({
  required bool animationsEnabled,
  required bool disableAnimations,
}) {
  return RefenaScope(
    key: UniqueKey(),
    overrides: [
      animationProvider.overrideWithBuilder((_) => animationsEnabled),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: disableAnimations),
          child: child!,
        );
      },
      home: const Scaffold(body: DevicePlaceholderListTile()),
    ),
  );
}

Widget _sendApp({
  required Device device,
  required SendTabVm vm,
  double textScale = 1,
  ThemeData? theme,
  bool animationsEnabled = false,
  bool disableAnimations = false,
  Set<String> runningIps = const {},
  List<RefenaObserver> observers = const [],
  GlobalKey<NavigatorState>? navigatorKey,
  Future<void> Function(FilePickerOption option)? onPickerOption,
}) {
  final settings = _fixtureSettings();
  return RefenaScope(
    key: UniqueKey(),
    observers: observers,
    overrides: [
      sendTabVmProvider.overrideWithBuilder((_) => vm),
      nearbyDevicesProvider.overrideWithNotifier(
        (_) => _FixtureNearbyDevicesService(device, runningIps: runningIps),
      ),
      settingsProvider.overrideWithNotifier(
        (_) => _FixtureSettingsService(settings),
      ),
      receiveHistoryProvider.overrideWithNotifier(
        (_) => _EmptyReceiveHistoryService(),
      ),
      animationProvider.overrideWithBuilder((_) => animationsEnabled),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      theme: theme ?? ThemeData(useMaterial3: true),
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
      home: _SendTestShell(onPickerOption: onPickerOption),
    ),
  );
}

class _SendTestShell extends StatelessWidget {
  final Future<void> Function(FilePickerOption option)? onPickerOption;

  const _SendTestShell({this.onPickerOption});

  @override
  Widget build(BuildContext context) {
    final controller = context.ref.watch(homePageControllerProvider).controller;
    return Scaffold(
      body: PageView(
        controller: controller,
        children: [
          SendTab(onPickerOption: onPickerOption),
          const SizedBox.shrink(),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

SendTabVm _fixtureVm(
  Device device,
  List<String> calls, {
  List<String> localIps = const [],
  List<SendMode>? selectedModes,
  List<CrossFile> selectedFiles = const [],
}) {
  return SendTabVm(
    sendMode: SendMode.single,
    selectedFiles: selectedFiles,
    localIps: localIps,
    nearbyDevices: [device],
    favoriteDevices: const [],
    onTapAddress: (_) async => calls.add('manual'),
    onTapFavorite: (_) async => calls.add('favorite'),
    onTapSendMode: (_, mode) async => selectedModes?.add(mode),
    onTapDevice: (_, _) async => calls.add('device'),
    onTapDeviceMultiSend: (_, _) async => calls.add('multi-device'),
  );
}

Device _fixtureDevice({
  bool https = false,
  String? ip = '192.168.1.42',
  int port = 53317,
  bool includeHttp = true,
  bool includeWebRtc = false,
}) {
  return Device(
    signalingId: includeWebRtc ? 'test-signaling-device' : null,
    ip: ip,
    version: '2.1.0',
    port: port,
    https: https,
    fingerprint: 'test-device-fingerprint',
    alias: 'Studio device',
    deviceModel: 'LocalSend test desktop',
    deviceType: DeviceType.desktop,
    download: false,
    channels: [
      if (includeHttp)
        HttpChannel(
          host: ip ?? '192.168.1.42',
          port: port,
          https: https,
        ),
      if (includeWebRtc) const SignalingChannel(signalingServer: 'https://signal.example'),
    ],
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

class _EmptyReceiveHistoryService extends ReceiveHistoryService {
  _EmptyReceiveHistoryService() : super(MockPersistenceService());

  @override
  List<ReceiveHistoryEntry> init() => const [];
}

class _FixtureNearbyDevicesService extends NearbyDevicesService {
  final Device device;
  final Set<String> runningIps;

  _FixtureNearbyDevicesService(this.device, {this.runningIps = const {}})
    : super(
        isolateController: IsolateController(initialState: _parentState()),
        favoriteService: FavoritesService(MockPersistenceService()),
        discoveryLogs: DiscoveryLogger(),
      );

  @override
  NearbyDevicesState init() => NearbyDevicesState(
    runningFavoriteScan: false,
    runningIps: runningIps,
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
