import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum M3eBackgroundEmphasis {
  receive(1),
  send(0.68),
  settings(0.38)
  ;

  const M3eBackgroundEmphasis(this.prominence);

  final double prominence;
}

/// A lightweight atmospheric background used by the three primary tabs.
///
/// The blobs are deliberately painted as clipped vector paths rather than
/// blurred bitmaps. This keeps the effect inexpensive while preserving the
/// expressive, organic M3E language across display sizes and themes.
class M3eExpressiveBackground extends StatefulWidget {
  final Widget child;
  final M3eBackgroundEmphasis emphasis;

  const M3eExpressiveBackground({
    required this.child,
    this.emphasis = M3eBackgroundEmphasis.receive,
    super.key,
  });

  @override
  State<M3eExpressiveBackground> createState() => _M3eExpressiveBackgroundState();
}

class _M3eExpressiveBackgroundState extends State<M3eExpressiveBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(bool enabled) {
    if (enabled && !_controller.isAnimating) {
      _controller.repeat(); // ignore: discarded_futures
    } else if (!enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animations = context.ref.watch(animationProvider);
    final scheme = Theme.of(context).colorScheme;
    final isOled = scheme.surface == Colors.black;
    final prominence = widget.emphasis.prominence;
    final oledAlphaScale = scheme.brightness == Brightness.dark ? 0.54 : 0.055;
    final primaryBlobColor = isOled
        ? scheme.surfaceContainerLow.withValues(
            alpha: oledAlphaScale * prominence,
          )
        : scheme.primaryContainer.withValues(alpha: 0.26 * prominence);
    final tertiaryBlobColor = isOled
        ? scheme.surfaceContainerHigh.withValues(
            alpha: oledAlphaScale * 0.82 * prominence,
          )
        : scheme.tertiaryContainer.withValues(alpha: 0.22 * prominence);
    final motionAllowed = animations && !MediaQuery.of(context).disableAnimations && !isOled;
    _syncAnimation(motionAllowed);

    final size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value * math.pi * 2;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              key: const ValueKey('m3e-background-surface'),
              color: scheme.surface,
            ),
            Positioned(
              left: -size.width * 0.46 + math.sin(progress * 0.92) * 14,
              top: -size.height * 0.16 + math.cos(progress * 0.74) * 12,
              child: _M3eBlob(
                colorKey: const ValueKey('m3e-background-primary-blob'),
                width: size.width * 0.86,
                height: size.height * 0.58,
                color: primaryBlobColor,
                rotation: -0.12 + math.sin(progress * 0.61) * 0.025,
                scale: 1.0 + math.sin(progress * 0.47) * 0.025,
              ),
            ),
            Positioned(
              right: -size.width * 0.42 + math.cos(progress * 0.68) * 16,
              bottom: size.height * 0.05 + math.sin(progress * 0.81) * 14,
              child: _M3eBlob(
                colorKey: const ValueKey('m3e-background-tertiary-blob'),
                width: size.width * 0.78,
                height: size.height * 0.54,
                color: tertiaryBlobColor,
                rotation: 0.14 + math.cos(progress * 0.52) * 0.03,
                scale: 1.0 + math.cos(progress * 0.39) * 0.03,
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _M3eBlob extends StatelessWidget {
  final Key? colorKey;
  final double width;
  final double height;
  final Color color;
  final double rotation;
  final double scale;

  const _M3eBlob({
    this.colorKey,
    required this.width,
    required this.height,
    required this.color,
    required this.rotation,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Transform.scale(
        scale: scale,
        child: RepaintBoundary(
          child: ClipPath(
            clipper: const _OrganicBlobClipper(),
            child: ColoredBox(
              key: colorKey,
              color: color,
              child: SizedBox(width: width, height: height),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganicBlobClipper extends CustomClipper<Path> {
  const _OrganicBlobClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.18, size.height * 0.18);
    path.cubicTo(
      size.width * 0.36,
      -size.height * 0.04,
      size.width * 0.76,
      size.height * 0.02,
      size.width * 0.90,
      size.height * 0.25,
    );
    path.cubicTo(
      size.width * 1.04,
      size.height * 0.49,
      size.width * 0.84,
      size.height * 0.84,
      size.width * 0.58,
      size.height * 0.91,
    );
    path.cubicTo(
      size.width * 0.31,
      size.height * 1.01,
      size.width * 0.04,
      size.height * 0.79,
      size.width * 0.08,
      size.height * 0.53,
    );
    path.cubicTo(
      size.width * 0.10,
      size.height * 0.38,
      size.width * 0.07,
      size.height * 0.28,
      size.width * 0.18,
      size.height * 0.18,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_OrganicBlobClipper oldClipper) => false;
}
