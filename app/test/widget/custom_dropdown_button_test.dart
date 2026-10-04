import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';

void main() {
  for (final mode in [ColorMode.localsend, ColorMode.custom, ColorMode.oled]) {
    for (final brightness in Brightness.values) {
      testWidgets('settings selectors retain their container and outline in ${mode.name}/${brightness.name}', (tester) async {
        final theme = getTheme(mode, Colors.deepOrange, brightness, null);
        String selected = 'one';
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 132,
                  child: StatefulBuilder(
                    builder: (context, setState) => CustomDropdownButton<String>(
                      value: selected,
                      items: const [
                        DropdownMenuItem(value: 'one', child: Text('One')),
                        DropdownMenuItem(value: 'two', child: Text('Two')),
                      ],
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final control = find.byType(CustomDropdownButton<String>);
        final material = tester.widget<Material>(find.descendant(of: control, matching: find.byType(Material)).first);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(material.color, theme.inputDecorationTheme.fillColor);
        expect(material.color!.a, greaterThan(0));
        expect(shape.side.width, greaterThan(0));
        expect(shape.side.color, theme.colorScheme.outlineVariant.withValues(alpha: 0.72));
        expect(shape.borderRadius, theme.inputDecorationTheme.borderRadius);
        await tester.tap(control);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Two').last);
        await tester.pumpAndSettle();
        expect(selected, 'two');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
