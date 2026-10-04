import 'package:flutter/material.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_isolates/util/sleep.dart';
import 'package:refena_flutter/refena_flutter.dart';

class InitialSlideTransition extends StatefulWidget {
  final Widget child;
  final Offset origin;
  final Offset destination;
  final Curve curve;
  final Duration duration;
  final Duration delay;

  const InitialSlideTransition({
    required this.child,
    this.origin = Offset.zero,
    this.destination = Offset.zero,
    this.curve = Curves.easeOutCubic,
    required this.duration,
    this.delay = Duration.zero,
    super.key,
  });

  @override
  State<InitialSlideTransition> createState() => _InitialSlideTransitionState();
}

class _InitialSlideTransitionState extends State<InitialSlideTransition> {
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.origin;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final delay = context.read(animationProvider) && !MediaQuery.disableAnimationsOf(context) ? widget.delay.inMilliseconds : 0;
      await sleepAsync(delay);
      if (!mounted) {
        return;
      }
      setState(() {
        _offset = widget.destination;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _offset,
      curve: widget.curve,
      duration: context.watch(animationProvider) && !MediaQuery.disableAnimationsOf(context) ? widget.duration : Duration.zero,
      child: widget.child,
    );
  }
}
