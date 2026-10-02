import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/widget/m3e/m3e_background.dart';
import 'package:refena_flutter/refena_flutter.dart';

const _surfaceKey = ValueKey('m3e-background-surface');
const _primaryBlobKey = ValueKey('m3e-background-primary-blob');
const _tertiaryBlobKey = ValueKey('m3e-background-tertiary-blob');

void main() {
  testWidgets(
    'organic shapes use tab emphasis and remain subtle over the black OLED surface',
    (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );
      const emphases = [
        (M3eBackgroundEmphasis.receive, 0.26, 0.22),
        (M3eBackgroundEmphasis.send, 0.26 * 0.68, 0.22 * 0.68),
        (M3eBackgroundEmphasis.settings, 0.26 * 0.38, 0.22 * 0.38),
      ];

      for (final (emphasis, primaryAlpha, tertiaryAlpha) in emphases) {
        await tester.pumpWidget(
          _backgroundApp(
            emphasis: emphasis,
            scheme: scheme,
            animationsEnabled: false,
          ),
        );
        expect(
          tester.widget<ColoredBox>(find.byKey(_primaryBlobKey)).color,
          scheme.primaryContainer.withValues(alpha: primaryAlpha),
        );
        expect(
          tester.widget<ColoredBox>(find.byKey(_tertiaryBlobKey)).color,
          scheme.tertiaryContainer.withValues(alpha: tertiaryAlpha),
        );
      }

      for (final brightness in [Brightness.light, Brightness.dark]) {
        final oledScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        ).copyWith(surface: Colors.black);
        await tester.pumpWidget(
          _backgroundApp(
            emphasis: M3eBackgroundEmphasis.receive,
            scheme: oledScheme,
            animationsEnabled: true,
          ),
        );

        expect(oledScheme.brightness, brightness);
        expect(
          tester.widget<ColoredBox>(find.byKey(_surfaceKey)).color,
          Colors.black,
        );
        final primaryBlob = tester.widget<ColoredBox>(find.byKey(_primaryBlobKey)).color;
        final tertiaryBlob = tester.widget<ColoredBox>(find.byKey(_tertiaryBlobKey)).color;
        expect(primaryBlob.a, greaterThan(0));
        expect(tertiaryBlob.a, greaterThan(0));
        expect(
          Color.alphaBlend(primaryBlob, Colors.black).computeLuminance(),
          lessThan(0.06),
        );
        expect(
          Color.alphaBlend(tertiaryBlob, Colors.black).computeLuminance(),
          lessThan(0.06),
        );
        expect(
          primaryBlob,
          oledScheme.surfaceContainerLow.withValues(
            alpha: brightness == Brightness.dark ? 0.54 : 0.055,
          ),
        );

        await tester.pump();
        final before = tester.getTopLeft(find.byKey(_primaryBlobKey));
        await tester.pump(const Duration(seconds: 4));
        final after = tester.getTopLeft(find.byKey(_primaryBlobKey));
        expect(
          (after - before).distance,
          lessThan(0.1),
          reason: 'OLED motion stays stopped for ${brightness.name} scheme brightness',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background motion requires both the app preference and system motion permission',
    (tester) async {
      const scenarios = [
        (true, false, true),
        (false, false, false),
        (true, true, false),
      ];

      for (final (appAnimationsEnabled, disableAnimations, shouldMove) in scenarios) {
        await tester.pumpWidget(
          _backgroundApp(
            emphasis: M3eBackgroundEmphasis.receive,
            scheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            animationsEnabled: appAnimationsEnabled,
            disableAnimations: disableAnimations,
          ),
        );
        await tester.pump();
        final before = tester.getTopLeft(find.byKey(_primaryBlobKey));
        await tester.pump(const Duration(seconds: 4));
        final after = tester.getTopLeft(find.byKey(_primaryBlobKey));

        if (shouldMove) {
          expect((after - before).distance, greaterThan(1));
        } else {
          expect((after - before).distance, lessThan(0.1));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Widget _backgroundApp({
  required M3eBackgroundEmphasis emphasis,
  required ColorScheme scheme,
  required bool animationsEnabled,
  bool disableAnimations = false,
}) {
  return RefenaScope(
    key: UniqueKey(),
    overrides: [
      animationProvider.overrideWithBuilder((_) => animationsEnabled),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true, colorScheme: scheme),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: disableAnimations),
          child: child!,
        );
      },
      home: M3eExpressiveBackground(
        emphasis: emphasis,
        child: const SizedBox.expand(),
      ),
    ),
  );
}
