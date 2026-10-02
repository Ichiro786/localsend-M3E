import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  testWidgets('expressive switch exposes state and toggles through its 48 dp hit region', (tester) async {
    var value = false;

    await tester.pumpWidget(
      RefenaScope(
        overrides: [
          animationProvider.overrideWithBuilder((_) => true),
        ],
        child: MaterialApp(
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
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.getSize(find.byType(M3eExpressiveSwitch)).height, greaterThanOrEqualTo(48));
    final hitBounds = tester.getRect(find.byType(InkWell));
    final trackBounds = tester.getRect(find.byType(AnimatedContainer).first);
    expect(hitBounds.size, const Size(52, 48));
    expect(trackBounds.size, const Size(52, 32));
    expect(trackBounds.top, greaterThan(hitBounds.top + 2));
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

    await tester.tapAt(Offset(hitBounds.center.dx, hitBounds.top + 2));
    await tester.pump(M3eTokens.shortMotion);

    expect(value, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('section headings use the theme title scale and on-surface color', (tester) async {
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: M3eSectionCard(title: 'Settings section', children: const [SizedBox(height: 1)]),
        ),
      ),
    );

    final heading = tester.widget<Text>(find.text('Settings section'));
    final resolvedTheme = Theme.of(tester.element(find.byType(M3eSectionCard)));
    expect(heading.style?.fontSize, resolvedTheme.textTheme.titleLarge?.fontSize);
    expect(heading.style?.fontWeight, FontWeight.w600);
    expect(heading.style?.color, resolvedTheme.colorScheme.onSurface);
    expect(tester.takeException(), isNull);
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

  testWidgets('floating navigation scopes blur, retains selected semantics and touch targets', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final tapped = <String>[];

    try {
      await tester.pumpWidget(
        _navigationHost(
          scheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
          animationsEnabled: true,
          tapped: tapped,
          selectedIndex: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(M3eFloatingNavigationBar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      for (final label in ['Receive', 'Send', 'Settings']) {
        expect(find.text(label), findsOneWidget);
        final target = find.ancestor(of: find.text(label), matching: find.byType(InkWell));
        expect(target, findsOneWidget);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      }

      final surfaceRect = tester.getRect(find.byKey(const ValueKey('m3e-floating-navigation-surface')));
      final clipRect = tester.getRect(find.byKey(const ValueKey('m3e-floating-navigation-clip')));
      final filterRect = tester.getRect(find.byType(BackdropFilter));
      expect(filterRect, surfaceRect);
      expect(clipRect, surfaceRect);
      expect(filterRect.width, lessThan(390));
      expect(filterRect.height, lessThan(844 / 2));

      final selectedRect = tester.getRect(find.byKey(const ValueKey('m3e-navigation-selected-pill')));
      expect(selectedRect.top - surfaceRect.top, greaterThanOrEqualTo(10));
      expect(surfaceRect.bottom - selectedRect.bottom, greaterThanOrEqualTo(10));

      final selectedData = tester.getSemantics(find.text('Send')).getSemanticsData();
      expect(selectedData.label, 'Send');
      expect(selectedData.flagsCollection.isButton, isTrue);
      expect(selectedData.flagsCollection.isSelected, Tristate.isTrue);
      expect(selectedData.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.text('Settings'));
      expect(tapped, ['Settings']);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('floating navigation uses theme tones and disables blur and transitions for reduced motion', (tester) async {
    final darkScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark);
    final dynamicScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light);
    final schemes = [
      ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
      darkScheme,
      dynamicScheme,
      darkScheme.copyWith(surface: Colors.black),
    ];

    for (final scheme in schemes) {
      await tester.pumpWidget(_navigationHost(scheme: scheme, animationsEnabled: true, tapped: []));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
      final blurredSurface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('m3e-floating-navigation-surface')),
      );
      expect(
        (blurredSurface.decoration as BoxDecoration).color,
        M3eTokens.elevatedSurface(scheme, opacity: 0.76),
      );
      final selectedPill = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('m3e-navigation-selected-pill')),
      );
      expect((selectedPill.decoration as BoxDecoration).color, scheme.primaryContainer);
      expect(tester.widget<Text>(find.text('Send')).style?.color, scheme.onPrimaryContainer);
      expect(tester.widget<Text>(find.text('Receive')).style?.color, scheme.onSurfaceVariant);

      await tester.pumpWidget(_navigationHost(scheme: scheme, animationsEnabled: false, tapped: []));
      expect(find.byType(BackdropFilter), findsNothing);
      final fallbackSurface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('m3e-floating-navigation-surface')),
      );
      expect(
        (fallbackSurface.decoration as BoxDecoration).color,
        M3eTokens.elevatedSurface(scheme, opacity: 0.94),
      );
      expect(
        tester.widget<AnimatedContainer>(find.byKey(const ValueKey('m3e-navigation-selected-pill'))).duration,
        Duration.zero,
      );

      await tester.pumpWidget(
        _navigationHost(scheme: scheme, animationsEnabled: true, disableAnimations: true, tapped: []),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.widget<AnimatedContainer>(find.byKey(const ValueKey('m3e-navigation-selected-pill'))).duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _navigationHost({
  required ColorScheme scheme,
  required bool animationsEnabled,
  required List<String> tapped,
  int selectedIndex = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorScheme: scheme),
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          padding: const EdgeInsets.only(bottom: 24),
          viewPadding: const EdgeInsets.only(bottom: 24),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      );
    },
    home: Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: const SizedBox.expand(child: ColoredBox(color: Color(0xFF00A896))),
      bottomNavigationBar: M3eFloatingNavigationBar(
        selectedIndex: selectedIndex,
        animationsEnabled: animationsEnabled,
        destinations: [
          M3eNavigationDestination(icon: Icons.download_for_offline_outlined, label: 'Receive', onTap: () => tapped.add('Receive')),
          M3eNavigationDestination(icon: Icons.send, label: 'Send', onTap: () => tapped.add('Send')),
          M3eNavigationDestination(icon: Icons.settings, label: 'Settings', onTap: () => tapped.add('Settings')),
        ],
      ),
    ),
  );
}
