import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  testWidgets('localized-style long text wraps naturally at narrow width', (
    tester,
  ) async {
    const title = 'Empfangene Prüfsummen prüfen';
    const supportingText = 'Dateien sicher und vollständig prüfen';

    await tester.pumpWidget(
      _settingsApp(
        width: 320,
        child: const M3eSettingsRow(
          icon: Icons.verified_outlined,
          title: title,
          supportingText: supportingText,
          semanticLabel: 'Receive checksum verification',
          trailing: M3eExpressiveSwitch(
            value: true,
            semanticLabel: 'Verify checksums, On',
            onChanged: null,
          ),
        ),
      ),
    );

    final titleFinder = find.text(title);
    final supportingFinder = find.text(supportingText);
    final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);
    final supportingParagraph = tester.renderObject<RenderParagraph>(
      supportingFinder,
    );
    final titleLines = _lineCount(tester, titleFinder, titleParagraph);
    final supportingLines = _lineCount(
      tester,
      supportingFinder,
      supportingParagraph,
    );
    final textWidth = titleParagraph.constraints.maxWidth;
    final textBottom = tester.getRect(supportingFinder).bottom;
    final switchRect = tester.getRect(find.byType(M3eExpressiveSwitch));
    expect(textWidth, greaterThanOrEqualTo(200));
    expect(titleLines, inInclusiveRange(2, 3));
    expect(supportingLines, inInclusiveRange(2, 3));
    expect(switchRect.top, greaterThanOrEqualTo(textBottom));
    expect(
      switchRect.height,
      greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'larger text scaling keeps the row readable and its control reachable',
    (tester) async {
      const title = 'Require a personal identification number';
      const supportingText = 'Ask before accepting files sent to this device';
      var switchTapped = false;

      await tester.pumpWidget(
        _settingsApp(
          width: 320,
          textScale: 1.8,
          child: M3eSettingsRow(
            icon: Icons.lock_outline,
            title: title,
            supportingText: supportingText,
            semanticLabel: 'PIN setting',
            trailing: M3eExpressiveSwitch(
              value: false,
              semanticLabel: 'Require PIN, Off',
              onChanged: (_) => switchTapped = true,
            ),
          ),
        ),
      );

      final titleRect = tester.getRect(find.text(title));
      final supportingRect = tester.getRect(find.text(supportingText));
      final switchRect = tester.getRect(find.byType(M3eExpressiveSwitch));

      expect(titleRect.height, greaterThan(40));
      expect(supportingRect.height, greaterThan(40));
      expect(switchRect.top, greaterThanOrEqualTo(supportingRect.bottom));
      expect(
        switchRect.height,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      await tester.ensureVisible(find.byType(M3eExpressiveSwitch));
      await tester.tap(find.byType(M3eExpressiveSwitch));
      expect(switchTapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide localized controls wrap below readable labels at 360 and 390dp',
    (tester) async {
      const title = 'Multicast-Adresse und IPv6-Gruppe';
      const supportingText = 'Nur Geräte im lokalen Netzwerk verwenden diese Adresse';

      for (final viewportWidth in [360.0, 390.0]) {
        final rowWidth = viewportWidth - 32;
        final controlSlotKey = ValueKey('ipv6-control-$viewportWidth');
        await tester.pumpWidget(
          _settingsApp(
            width: rowWidth,
            child: M3eSettingsRow(
              key: ValueKey('ipv6-row-$viewportWidth'),
              icon: Icons.cell_tower_outlined,
              title: title,
              supportingText: supportingText,
              semanticLabel: 'IPv6 address setting',
              preferredTrailingWidth: 220,
              trailing: SizedBox(
                key: controlSlotKey,
                width: 220,
                height: 56,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: M3eExpressiveSwitch(
                    value: true,
                    semanticLabel: 'IPv6 address input, On',
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text(title);
        final supportingFinder = find.text(supportingText);
        final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);
        final rowRect = tester.getRect(find.byKey(ValueKey('ipv6-row-$viewportWidth')));
        final controlRect = tester.getRect(find.byKey(controlSlotKey));
        final switchRect = tester.getRect(find.byType(M3eExpressiveSwitch));
        expect(titleParagraph.constraints.maxWidth, greaterThanOrEqualTo(200));
        expect(controlRect.width, 220);
        expect(controlRect.top, greaterThanOrEqualTo(tester.getRect(supportingFinder).bottom));
        expect(controlRect.right, lessThanOrEqualTo(rowRect.right));
        expect(switchRect.height, M3eTokens.settingsRowControlMinimumSize);
        expect(find.bySemanticsLabel('IPv6 address setting'), findsOneWidget);
        expect(find.bySemanticsLabel('IPv6 address input, On'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'toggle, value, and action trailing slots share the same trailing edge',
    (tester) async {
      await tester.pumpWidget(
        _settingsApp(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3eSettingsRow(
                icon: Icons.animation,
                title: 'Animations',
                semanticLabel: 'Animations setting',
                trailing: SizedBox(
                  key: const ValueKey('toggle-slot'),
                  width: 64,
                  height: 48,
                  child: Center(
                    child: M3eExpressiveSwitch(
                      value: true,
                      semanticLabel: 'Animations, On',
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
              M3eSettingsRow(
                icon: Icons.palette_outlined,
                title: 'Color scheme',
                semanticLabel: 'Color scheme setting',
                trailing: SizedBox(
                  key: const ValueKey('value-slot'),
                  width: 104,
                  height: 48,
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Text('OLED'),
                  ),
                ),
              ),
              M3eSettingsRow(
                icon: Icons.folder_open_outlined,
                title: 'Destination',
                semanticLabel: 'Choose destination',
                trailing: SizedBox(
                  key: const ValueKey('action-slot'),
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final toggleRect = tester.getRect(
        find.byKey(const ValueKey('toggle-slot')),
      );
      final valueRect = tester.getRect(
        find.byKey(const ValueKey('value-slot')),
      );
      final actionRect = tester.getRect(
        find.byKey(const ValueKey('action-slot')),
      );

      expect(
        toggleRect.width,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      expect(
        valueRect.height,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      expect(
        actionRect.width,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      expect(toggleRect.right, closeTo(valueRect.right, 0.1));
      expect(valueRect.right, closeTo(actionRect.right, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'row and trailing switch expose accessible labels, actions, and state',
    (tester) async {
      var rowTapCount = 0;
      var switchValue = false;

      await tester.pumpWidget(
        _settingsApp(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3eSettingsRow(
                key: const ValueKey('value-row'),
                icon: Icons.language,
                title: 'Language',
                supportingText: 'Choose the app language',
                semanticLabel: 'Language setting, currently System',
                trailing: const Text('System'),
                onTap: () => rowTapCount++,
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  return M3eSettingsRow(
                    icon: Icons.animation,
                    title: 'Animations',
                    semanticLabel: 'Animations setting',
                    trailing: M3eExpressiveSwitch(
                      value: switchValue,
                      semanticLabel: 'Animations',
                      onChanged: (value) => setState(() => switchValue = value),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const ValueKey('value-row'))),
        matchesSemantics(
          label: 'Language setting, currently System',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byType(M3eExpressiveSwitch)),
        matchesSemantics(
          label: 'Animations',
          isEnabled: true,
          hasEnabledState: true,
          isToggled: false,
          hasToggledState: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('value-row')));
      expect(rowTapCount, 1);
      await tester.tap(find.byType(M3eExpressiveSwitch));
      expect(switchValue, isTrue);
    },
  );

  testWidgets(
    'row hit areas and trailing controls meet the accessible minimum',
    (tester) async {
      var switchValue = false;
      await tester.pumpWidget(
        _settingsApp(
          width: 320,
          child: StatefulBuilder(
            builder: (context, setState) {
              return M3eSettingsRow(
                key: const ValueKey('action-row'),
                icon: Icons.info_outline,
                title: 'Advanced settings',
                semanticLabel: 'Open advanced settings',
                trailing: M3eExpressiveSwitch(
                  value: switchValue,
                  semanticLabel: 'Row test switch',
                  onChanged: (value) => setState(() => switchValue = value),
                ),
                onTap: () {},
              );
            },
          ),
        ),
      );

      final rowHitTarget = tester.getSize(
        find
            .descendant(
              of: find.byKey(const ValueKey('action-row')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final switchHitBounds = tester.getRect(
        find.descendant(
          of: find.byType(M3eExpressiveSwitch),
          matching: find.byType(InkWell),
        ),
      );
      final trackBounds = tester.getRect(
        find
            .descendant(
              of: find.byType(M3eExpressiveSwitch),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final iconSlot = tester.getSize(find.byType(M3eSettingsIcon));
      expect(
        rowHitTarget.height,
        greaterThanOrEqualTo(M3eTokens.settingsRowControlMinimumSize),
      );
      expect(switchHitBounds.height, M3eTokens.settingsRowControlMinimumSize);
      expect(trackBounds.height, 32);
      expect(trackBounds.top, greaterThan(switchHitBounds.top + 2));
      expect(
        iconSlot,
        const Size(
          M3eTokens.settingsIconContainerSize,
          M3eTokens.settingsIconContainerSize,
        ),
      );
      await tester.tapAt(
        Offset(switchHitBounds.center.dx, switchHitBounds.top + 2),
      );
      await tester.pump(M3eTokens.shortMotion);
      expect(switchValue, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'icon, section surface, and row colors follow light, dark, and OLED schemes',
    (tester) async {
      final lightScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.light,
      );
      final darkScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      );
      final oledScheme = darkScheme.copyWith(surface: Colors.black);
      final schemes = [lightScheme, darkScheme, oledScheme];

      for (final scheme in schemes) {
        final theme = ThemeData(useMaterial3: true, colorScheme: scheme);
        await tester.pumpWidget(
          _settingsApp(
            width: 420,
            theme: theme,
            child: const M3eSettingsRow(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              supportingText: 'Follow system or choose a theme',
              semanticLabel: 'Theme setting',
              trailing: Text('Dark'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconBox = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(M3eSettingsIcon),
            matching: find.byType(DecoratedBox),
          ),
        );
        final iconDecoration = iconBox.decoration as BoxDecoration;
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(M3eSettingsIcon),
            matching: find.byType(Icon),
          ),
        );
        final card = tester.widget<Card>(find.byType(Card));
        final activeScheme = Theme.of(
          tester.element(find.byType(M3eSettingsIcon)),
        ).colorScheme;

        expect(activeScheme.primaryContainer, scheme.primaryContainer);
        expect(iconDecoration.color, activeScheme.tertiaryContainer);
        expect(icon.color, activeScheme.onTertiaryContainer);
        expect(card.color, M3eTokens.surface(activeScheme, opacity: 0.82));
        expect(find.bySemanticsLabel('Theme setting'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      expect(oledScheme.surface, Colors.black);
    },
  );

  testWidgets('expressive switch respects app and system reduced-motion settings', (
    tester,
  ) async {
    for (final configuration in [
      (animationsEnabled: true, disableAnimations: false, expected: M3eTokens.shortMotion),
      (animationsEnabled: false, disableAnimations: false, expected: Duration.zero),
      (animationsEnabled: true, disableAnimations: true, expected: Duration.zero),
    ]) {
      await tester.pumpWidget(
        _settingsApp(
          width: 320,
          animationsEnabled: configuration.animationsEnabled,
          disableAnimations: configuration.disableAnimations,
          child: const M3eExpressiveSwitch(
            value: false,
            semanticLabel: 'Animation test',
            onChanged: null,
          ),
        ),
      );
      final track = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(track.duration, configuration.expected);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('all Settings row icons resolve to explicit semantic theme roles', (
    tester,
  ) async {
    final iconRoles = <IconData, M3eSettingsAccent>{
      Icons.palette_outlined: M3eSettingsAccent.secondary,
      Icons.vertical_align_bottom: M3eSettingsAccent.secondary,
      Icons.power_settings_new: M3eSettingsAccent.secondary,
      Icons.favorite_border: M3eSettingsAccent.secondary,
      Icons.folder_open_outlined: M3eSettingsAccent.secondary,
      Icons.history: M3eSettingsAccent.secondary,
      Icons.fingerprint: M3eSettingsAccent.secondary,
      Icons.badge_outlined: M3eSettingsAccent.secondary,
      Icons.numbers: M3eSettingsAccent.secondary,
      Icons.wifi_tethering_outlined: M3eSettingsAccent.secondary,
      Icons.dns_outlined: M3eSettingsAccent.secondary,
      Icons.policy_outlined: M3eSettingsAccent.secondary,
      Icons.info_outline: M3eSettingsAccent.secondary,
      Icons.dark_mode_outlined: M3eSettingsAccent.tertiary,
      Icons.language: M3eSettingsAccent.tertiary,
      Icons.window_outlined: M3eSettingsAccent.tertiary,
      Icons.download_outlined: M3eSettingsAccent.tertiary,
      Icons.done_all: M3eSettingsAccent.tertiary,
      Icons.animation_outlined: M3eSettingsAccent.tertiary,
      Icons.verified_outlined: M3eSettingsAccent.tertiary,
      Icons.link: M3eSettingsAccent.tertiary,
      Icons.devices_outlined: M3eSettingsAccent.tertiary,
      Icons.smartphone: M3eSettingsAccent.tertiary,
      Icons.timer_outlined: M3eSettingsAccent.tertiary,
      Icons.cell_tower_outlined: M3eSettingsAccent.tertiary,
      Icons.gavel_outlined: M3eSettingsAccent.tertiary,
      Icons.tune: M3eSettingsAccent.tertiary,
      Icons.minimize: M3eSettingsAccent.primary,
      Icons.more_horiz: M3eSettingsAccent.primary,
      Icons.photo_library_outlined: M3eSettingsAccent.primary,
      Icons.shield_outlined: M3eSettingsAccent.primary,
      Icons.lock_outline: M3eSettingsAccent.tertiary,
    };
    final schemes = [
      ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      ),
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      ).copyWith(surface: Colors.black),
    ];

    for (final scheme in schemes) {
      await tester.pumpWidget(
        _settingsApp(
          width: 320,
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final icon in iconRoles.keys) M3eSettingsIcon(icon: icon),
            ],
          ),
        ),
      );
      for (final entry in iconRoles.entries) {
        final iconFinder = find.byIcon(entry.key);
        final component = find.ancestor(
          of: iconFinder,
          matching: find.byType(M3eSettingsIcon),
        );
        final box = tester.widget<DecoratedBox>(
          find.descendant(of: component, matching: find.byType(DecoratedBox)),
        );
        final expectedContainer = switch (entry.value) {
          M3eSettingsAccent.primary => scheme.primaryContainer,
          M3eSettingsAccent.secondary => scheme.secondaryContainer,
          M3eSettingsAccent.tertiary => scheme.tertiaryContainer,
          M3eSettingsAccent.error => scheme.errorContainer,
        };
        expect(
          (box.decoration as BoxDecoration).color,
          expectedContainer,
          reason: '${entry.key} must use its explicit M3 role',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('picker accents resolve to six distinct Material tonal roles', (
    tester,
  ) async {
    final schemes = [
      ColorScheme.fromSeed(seedColor: const Color(0xFF006A60)),
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      ),
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A60),
        brightness: Brightness.dark,
      ).copyWith(surface: Colors.black),
    ];

    for (final scheme in schemes) {
      await tester.pumpWidget(
        _settingsApp(
          width: 640,
          theme: ThemeData(useMaterial3: true, colorScheme: scheme),
          child: Wrap(
            children: [
              for (final accent in M3eSelectionAccent.values)
                SizedBox(
                  width: 96,
                  child: M3eSelectionCard(
                    icon: Icons.insert_drive_file_outlined,
                    label: accent.name,
                    accent: accent,
                    onTap: () {},
                  ),
                ),
            ],
          ),
        ),
      );

      final iconContainers = <Color>{};
      for (final card in find.byType(M3eSelectionCard).evaluate()) {
        final cardFinder = find.byWidget(card.widget);
        final circle = find.descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is DecoratedBox && widget.decoration is BoxDecoration && (widget.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        expect(circle, findsOneWidget);
        final decoration = tester.widget<DecoratedBox>(circle).decoration as BoxDecoration;
        iconContainers.add(decoration.color!);
      }
      expect(iconContainers, hasLength(M3eSelectionAccent.values.length));
      expect(tester.takeException(), isNull);
    }
  });
}

int _lineCount(WidgetTester tester, Finder finder, RenderParagraph paragraph) {
  final element = tester.element(finder);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: Directionality.of(element),
    textScaler: MediaQuery.textScalerOf(element),
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  return painter.computeLineMetrics().length;
}

Widget _settingsApp({
  required Widget child,
  required double width,
  double textScale = 1,
  ThemeData? theme,
  bool animationsEnabled = true,
  bool disableAnimations = false,
}) {
  return RefenaScope(
    key: UniqueKey(),
    overrides: [
      animationProvider.overrideWithBuilder((_) => animationsEnabled),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true),
      home: Builder(
        builder: (context) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: M3eSectionCard(title: 'Settings', children: [child]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
