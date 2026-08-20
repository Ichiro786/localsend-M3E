import 'package:flutter/material.dart';

/// Shared presentation tokens for the LocalSend M3E redesign.
///
/// These tokens intentionally describe geometry and semantic relationships,
/// not screenshot-specific colors or device-specific coordinates.
abstract final class M3eTokens {
  static const double controlRadius = 16;
  static const double cardRadius = 28;
  static const double navigationRadius = 34;
  static const double controlHeight = 56;
  static const double compactGap = 8;
  static const double standardGap = 12;
  static const double sectionGap = 18;
  // Semantic motion tokens preserve the approved Phase 2 timings while giving
  // Phase 3 interactions one shared vocabulary.
  static const Duration microMotion = Duration(milliseconds: 140);
  static const Duration shortMotion = Duration(milliseconds: 180);
  static const Duration standardMotion = Duration(milliseconds: 220);
  static const Duration entranceMotion = Duration(milliseconds: 300);
  static const Duration expressiveMotion = Duration(milliseconds: 400);
  static const Curve responsiveCurve = Curves.easeOutCubic;
  static const Curve expressiveCurve = responsiveCurve;

  static BorderSide outline(ColorScheme scheme, {double opacity = 0.45}) {
    return BorderSide(color: scheme.outlineVariant.withValues(alpha: opacity));
  }

  static Color surface(ColorScheme scheme, {double opacity = 0.84}) {
    return scheme.surfaceContainerLow.withValues(alpha: opacity);
  }

  static Color elevatedSurface(ColorScheme scheme, {double opacity = 0.92}) {
    return scheme.surfaceContainerHigh.withValues(alpha: opacity);
  }
}
