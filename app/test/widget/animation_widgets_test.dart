import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/rotating_widget.dart';

void main() {
  testWidgets('opacity slideshow does not advance while animations are disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OpacitySlideshow(
          durationMillis: 100,
          running: false,
          children: [
            Text('first'),
            Text('second'),
          ],
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('rotating widget pauses and resumes without replacing its child', (tester) async {
    var spinning = true;
    const childKey = ValueKey('rotating-child');

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return RotatingWidget(
              duration: const Duration(milliseconds: 200),
              spinning: spinning,
              child: const SizedBox(key: childKey, width: 24, height: 24),
            );
          },
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(childKey), findsOneWidget);

    spinning = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return RotatingWidget(
              duration: const Duration(milliseconds: 200),
              spinning: spinning,
              child: const SizedBox(key: childKey, width: 24, height: 24),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(childKey), findsOneWidget);
  });
}
