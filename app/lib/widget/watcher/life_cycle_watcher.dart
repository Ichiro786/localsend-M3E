import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/ui/animations_status.dart';
import 'package:refena_flutter/refena_flutter.dart';

class LifeCycleWatcher extends StatefulWidget {
  final Widget child;
  final void Function(AppLifecycleState state) onChangedState;

  const LifeCycleWatcher({required this.child, required this.onChangedState, super.key});

  @override
  State<LifeCycleWatcher> createState() => _LifeCycleWatcherState();
}

class _LifeCycleWatcherState extends State<LifeCycleWatcher> with WidgetsBindingObserver {
  int _motionRequest = 0;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.onChangedState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshMotionPreference());
    }
  }
  @override
  void didChangeAccessibilityFeatures() {
    // Apply Flutter's accessibility signal immediately, then reconcile native
    // reduce-motion settings (including platforms with a separate API).
    final reduced = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    context.ref.notifier(reducedMotionProvider).setState((_) => reduced);
    unawaited(_refreshMotionPreference());
  }

  Future<void> _refreshMotionPreference() async {
    final request = ++_motionRequest;
    final systemAnimations = await getSystemAnimationsStatus();
    if (!mounted || request != _motionRequest) return;
    final reduced = !systemAnimations || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    context.ref.notifier(reducedMotionProvider).setState((_) => reduced);
  }

}
