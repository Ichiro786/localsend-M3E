import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/animations/initial_slide_transition.dart';
import 'package:localsend_app/widget/watcher/life_cycle_watcher.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => timeDilation = 1);

  test('motion defaults on and follows accessibility and sleep without a saved preference', () {
    final container = RefenaContainer();
    addTearDown(container.disposeContainer);
    expect(container.read(animationProvider), isTrue);
    container.notifier(reducedMotionProvider).setState((_) => true);
    expect(container.read(animationProvider), isFalse);
    container.notifier(reducedMotionProvider).setState((_) => false);
    expect(container.read(animationProvider), isTrue);
    container.notifier(sleepProvider).setState((_) => true);
    expect(container.read(animationProvider), isFalse);
    container.notifier(reducedMotionProvider).setState((_) => true);
    container.notifier(sleepProvider).setState((_) => false);
    expect(container.read(animationProvider), isFalse);
  });

  testWidgets('platform accessibility changes and resumes keep reduced motion current', (tester) async {
    final container = RefenaContainer();
    addTearDown(container.disposeContainer);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        ownsContainer: false,
        child: LifeCycleWatcher(
          onChangedState: (_) {},
          child: const MaterialApp(home: SizedBox()),
        ),
      ),
    );
    for (final reduced in [true, false, true, false]) {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduced);
      await tester.pump();
      expect(container.read(animationProvider), !reduced);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(animationProvider), !reduced);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entrance effects become immediately visible with platform reduced motion', (tester) async {
    await tester.pumpWidget(
      RefenaScope(
        overrides: [reducedMotionProvider.overrideWithInitialState((_) => true)],
        child: const MaterialApp(
          home: Column(
            children: [
              InitialFadeTransition(delay: Duration(seconds: 5), duration: Duration(seconds: 1), child: Text('Fade')),
              InitialSlideTransition(origin: Offset(0, 1), delay: Duration(seconds: 5), duration: Duration(seconds: 1), child: Text('Slide')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump();
    final fade = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(fade.opacity, 1);
    expect(fade.duration, Duration.zero);
    expect(slide.offset, Offset.zero);
    expect(slide.duration, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('removing delayed entrance effects cancels their pending timers', (tester) async {
    await tester.pumpWidget(
      RefenaScope(
        child: const MaterialApp(
          home: Column(children: [
            InitialFadeTransition(delay: Duration(seconds: 5), duration: Duration(seconds: 1), child: Text('Fade')),
            InitialSlideTransition(origin: Offset(0, 1), delay: Duration(seconds: 5), duration: Duration(seconds: 1), child: Text('Slide')),
          ]),
        ),
      ),
    );
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 0);
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset, const Offset(0, 1));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    // Flutter verifies there are no pending timers at the end of this test.
  });

}
