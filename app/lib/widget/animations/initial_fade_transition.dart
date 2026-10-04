import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class InitialFadeTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const InitialFadeTransition({
    required this.child,
    required this.duration,
    this.delay = Duration.zero,
    super.key,
  });

  @override
  State<InitialFadeTransition> createState() => _InitialFadeTransitionState();
}

class _InitialFadeTransitionState extends State<InitialFadeTransition> {
  double _opacity = 0;

  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delay = context.read(animationProvider) && !MediaQuery.disableAnimationsOf(context) ? widget.delay : Duration.zero;
      if (delay == Duration.zero) {
        _show();
      } else {
        _delayTimer = Timer(delay, _show);
      }
    });
  }

  void _show() {
    if (!mounted) return;
    setState(() {
      _opacity = 1;
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motionAllowed = context.watch(animationProvider) && !MediaQuery.disableAnimationsOf(context);
    if (!motionAllowed) {
      _delayTimer?.cancel();
      _opacity = 1;
    }
    return AnimatedOpacity(
      opacity: _opacity,
      duration: motionAllowed ? widget.duration : Duration.zero,
      child: widget.child,
    );
  }
}
