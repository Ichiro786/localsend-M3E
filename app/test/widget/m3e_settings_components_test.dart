import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';

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

      await tester.pumpWidget(
        _settingsApp(
          width: 320,
          textScale: 1.8,
          child: const M3eSettingsRow(
            icon: Icons.lock_outline,
            title: title,
            supportingText: supportingText,
            semanticLabel: 'PIN setting',
            trailing: M3eExpressiveSwitch(
              value: false,
              semanticLabel: 'Require PIN, Off',
              onChanged: null,
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
      expect(tester.takeException(), isNull);
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
        expect(iconDecoration.color, activeScheme.primaryContainer);
        expect(icon.color, activeScheme.onPrimaryContainer);
        expect(card.color, M3eTokens.surface(activeScheme, opacity: 0.82));
        expect(find.bySemanticsLabel('Theme setting'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      expect(oledScheme.surface, Colors.black);
    },
  );
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
}) {
  return MaterialApp(
    theme: theme ?? ThemeData(useMaterial3: true),
    home: Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
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
  );
}
