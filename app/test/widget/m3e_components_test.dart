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
}
