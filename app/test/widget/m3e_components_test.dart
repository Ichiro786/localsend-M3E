import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';

void main() {
  testWidgets('expressive switch exposes state and toggles through its touch target', (tester) async {
    var value = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Center(
                child: M3eExpressiveSwitch(
                  value: value,
                  semanticLabel: 'Animations, Off',
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.getSize(find.byType(M3eExpressiveSwitch)).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byType(M3eExpressiveSwitch)),
      matchesSemantics(
        label: 'Animations, Off',
        isEnabled: true,
        hasEnabledState: true,
        isToggled: false,
        hasToggledState: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump(M3eTokens.shortMotion);

    expect(value, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('floating navigation leaves the app body behind its transparent slot in both themes', (tester) async {
    const pageBackground = Color(0xFF00A896);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: brightness),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                padding: const EdgeInsets.only(bottom: 24),
                viewPadding: const EdgeInsets.only(bottom: 24),
              ),
              child: child!,
            );
          },
          home: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: const SizedBox.expand(
              child: ColoredBox(
                key: ValueKey('page-body-background'),
                color: pageBackground,
              ),
            ),
            bottomNavigationBar: M3eFloatingNavigationBar(
              selectedIndex: 0,
              destinations: [
                M3eNavigationDestination(icon: Icons.home_outlined, label: 'Home', onTap: () {}),
                M3eNavigationDestination(icon: Icons.send, label: 'Send', onTap: () {}),
                M3eNavigationDestination(icon: Icons.settings, label: 'Settings', onTap: () {}),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getRect(find.byKey(const ValueKey('page-body-background'))).bottom,
        tester.getRect(find.byType(Scaffold)).bottom,
      );
      final safeArea = tester.widget<SafeArea>(
        find.descendant(of: find.byType(M3eFloatingNavigationBar), matching: find.byType(SafeArea)),
      );
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isTrue);
      expect(safeArea.minimum, const EdgeInsets.fromLTRB(16, 8, 16, 10));
    }
  });
}
