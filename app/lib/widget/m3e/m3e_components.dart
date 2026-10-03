import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';

class M3eMotionAwareCrossFade extends StatelessWidget {
  final bool motionAllowed;
  final CrossFadeState crossFadeState;
  final Duration duration;
  final Alignment alignment;
  final Widget firstChild;
  final Widget secondChild;

  const M3eMotionAwareCrossFade({
    required this.motionAllowed,
    required this.crossFadeState,
    required this.duration,
    required this.alignment,
    required this.firstChild,
    required this.secondChild,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!motionAllowed) {
      return crossFadeState == CrossFadeState.showSecond ? secondChild : firstChild;
    }

    return AnimatedCrossFade(
      crossFadeState: crossFadeState,
      duration: duration,
      alignment: alignment,
      firstChild: firstChild,
      secondChild: secondChild,
    );
  }
}

class M3eExpressiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  final bool animationsEnabled;

  const M3eExpressiveSwitch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.animationsEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motionDuration = animationsEnabled && !MediaQuery.disableAnimationsOf(context) ? M3eTokens.shortMotion : Duration.zero;
    final enabled = onChanged != null;
    final trackColor = value ? scheme.primary : scheme.surfaceContainerHighest;
    final thumbColor = value ? scheme.onPrimary : scheme.outline;
    final iconColor = value ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            width: 52,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: motionDuration,
                curve: M3eTokens.expressiveCurve,
                width: 52,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: enabled ? trackColor : trackColor.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: value ? scheme.primary.withValues(alpha: 0.25) : scheme.outlineVariant,
                  ),
                ),
                child: AnimatedAlign(
                  duration: motionDuration,
                  curve: M3eTokens.expressiveCurve,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: motionDuration,
                    curve: M3eTokens.expressiveCurve,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: thumbColor, shape: BoxShape.circle),
                    child: AnimatedSwitcher(
                      duration: motionDuration,
                      child: Icon(
                        value ? Icons.check : Icons.close,
                        key: ValueKey(value),
                        size: 16,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class M3eIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool selected;

  const M3eIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          maximumSize: const Size(56, 56),
          padding: const EdgeInsets.all(13),
          foregroundColor: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          backgroundColor: selected ? scheme.primaryContainer : M3eTokens.elevatedSurface(scheme, opacity: 0.86),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          disabledBackgroundColor: scheme.surfaceContainerLow.withValues(alpha: 0.62),
          shape: const CircleBorder(),
          side: BorderSide(
            color: selected ? scheme.primary.withValues(alpha: 0.36) : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class M3eSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Widget? leading;
  final String? supportingText;

  const M3eSectionCard({
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(22, 22, 22, 10),
    this.leading,
    this.supportingText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: M3eTokens.surface(scheme, opacity: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (supportingText != null) ...[
              const SizedBox(height: M3eTokens.compactGap),
              Text(supportingText!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class M3eSettingsIcon extends StatelessWidget {
  final IconData icon;

  const M3eSettingsIcon({required this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: M3eTokens.settingsIconContainerSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: M3eTokens.settingsIconSize,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row with a caller-selected icon, accessible label, and trailing control.
///
/// The trailing slot is intentionally composable so callers can reuse existing
/// switches, value controls, dialogs, routes, or actions without coupling this
/// presentation primitive to settings state or localized text.
class M3eSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? supportingText;
  final Widget trailing;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double? preferredTrailingWidth;

  const M3eSettingsRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.semanticLabel,
    this.supportingText,
    this.onTap,
    this.preferredTrailingWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            if (supportingText != null) ...[
              const SizedBox(height: 2),
              Text(
                supportingText!,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
        final leading = M3eSettingsIcon(icon: icon);
        final trailingWidth = (preferredTrailingWidth ?? constraints.maxWidth * 0.4).clamp(48.0, constraints.maxWidth).toDouble();
        final minimumInlineWidth =
            M3eTokens.settingsIconContainerSize +
            M3eTokens.standardGap * 2 +
            M3eTokens.settingsRowMinimumLabelWidth * MediaQuery.textScalerOf(context).scale(1) +
            trailingWidth;
        final trailingSlot = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: M3eTokens.settingsRowControlMinimumSize,
            minHeight: M3eTokens.settingsRowControlMinimumSize,
            maxWidth: trailingWidth,
          ),
          child: trailing,
        );

        if (constraints.maxWidth <= M3eTokens.settingsRowCompactBreakpoint || constraints.maxWidth < minimumInlineWidth) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: M3eTokens.standardGap),
                  Expanded(child: text),
                ],
              ),
              const SizedBox(height: M3eTokens.compactGap),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailingSlot,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: M3eTokens.standardGap),
            Expanded(child: text),
            const SizedBox(width: M3eTokens.standardGap),
            trailingSlot,
          ],
        );
      },
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      button: onTap != null,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(M3eTokens.controlRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: M3eTokens.settingsRowControlMinimumSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: M3eTokens.compactGap),
            child: content,
          ),
        ),
      ),
    );
  }
}

class M3eSelectionCard extends StatefulWidget {
  static const double _horizontalPadding = 10;
  static const double _verticalPadding = 12;
  static const double _iconPadding = 14;
  static const double _iconSize = 28;

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final bool animationsEnabled;

  const M3eSelectionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.animationsEnabled = true,
    super.key,
  });

  static double requiredHeightForLabel({
    required BuildContext context,
    required String label,
    required double cardWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: Theme.of(context).textTheme.titleMedium),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    painter.layout(maxWidth: (cardWidth - _horizontalPadding * 2).clamp(0.0, double.infinity).toDouble());
    final height = _verticalPadding * 2 + _iconPadding * 2 + _iconSize + M3eTokens.compactGap + painter.height;
    painter.dispose();
    return height.ceilToDouble();
  }

  @override
  State<M3eSelectionCard> createState() => _M3eSelectionCardState();
}

class _M3eSelectionCardState extends State<M3eSelectionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = widget.icon;
    final label = widget.label;
    final onTap = widget.onTap;
    final emphasized = widget.emphasized || _pressed;
    final motionAllowed = widget.animationsEnabled && !MediaQuery.disableAnimationsOf(context);
    final background = emphasized ? scheme.primaryContainer.withValues(alpha: 0.78) : scheme.surfaceContainerLow.withValues(alpha: 0.84);
    final foreground = emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    return AnimatedScale(
      scale: _pressed && motionAllowed ? 0.96 : 1,
      duration: motionAllowed ? M3eTokens.microMotion : Duration.zero,
      curve: M3eTokens.expressiveCurve,
      child: Semantics(
        button: true,
        label: label,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: M3eSelectionCard._horizontalPadding, vertical: M3eSelectionCard._verticalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: emphasized ? scheme.primaryContainer : scheme.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(M3eSelectionCard._iconPadding),
                      child: Icon(icon, size: M3eSelectionCard._iconSize, color: emphasized ? foreground : scheme.onPrimaryFixed),
                    ),
                  ),
                  const SizedBox(height: M3eTokens.compactGap),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class M3eFloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final List<M3eNavigationDestination> destinations;
  final bool animationsEnabled;

  const M3eFloatingNavigationBar({
    required this.selectedIndex,
    required this.destinations,
    this.animationsEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motionAllowed = animationsEnabled && !MediaQuery.disableAnimationsOf(context);
    final surfaceOpacity = !motionAllowed ? 0.9 : (scheme.brightness == Brightness.dark ? 0.4 : 0.55);
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MediaQuery.paddingOf(context);
        final width = constraints.maxWidth - math.max(16, padding.left) - math.max(16, padding.right);
        final destinationWidth = (width - M3eTokens.navigationInset * 2) / destinations.length;
        var destinationHeight = 48.0;
        for (var index = 0; index < destinations.length; index++) {
          final painter = TextPainter(
            text: TextSpan(
              text: destinations[index].label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: index == selectedIndex ? FontWeight.w700 : FontWeight.w500),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
            ellipsis: '…',
          )..layout(maxWidth: math.max(0, destinationWidth - 20));
          destinationHeight = math.max(destinationHeight, 25 + 4 + painter.height + 20);
          painter.dispose();
        }
        final height = destinationHeight + M3eTokens.navigationInset * 2;
        // Keep the highlight and outer border concentric even when large labels
        // make a destination taller than it is wide.
        final outerRadius = math.min(height / 2, destinationWidth / 2 + M3eTokens.navigationInset);
        final borderRadius = BorderRadius.circular(outerRadius);
        final navigationSurface = SizedBox(
          height: height,
          child: DecoratedBox(
            key: const ValueKey('m3e-floating-navigation-surface'),
            decoration: BoxDecoration(
              color: M3eTokens.elevatedSurface(scheme, opacity: surfaceOpacity),
              borderRadius: borderRadius,
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(M3eTokens.navigationInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _M3eNavigationDestination(
                        destination: destinations[index],
                        selected: index == selectedIndex,
                        animationsEnabled: motionAllowed,
                        cornerRadius: outerRadius - M3eTokens.navigationInset,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        final clippedSurface = ClipRRect(
          key: const ValueKey('m3e-floating-navigation-clip'),
          borderRadius: borderRadius,
          child: motionAllowed
              ? BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: M3eTokens.frostedBlurSigma, sigmaY: M3eTokens.frostedBlurSigma),
                  child: navigationSurface,
                )
              : navigationSurface,
        );
        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: clippedSurface,
          ),
        );
      },
    );
  }
}

class M3eNavigationDestination {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const M3eNavigationDestination({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _M3eNavigationDestination extends StatelessWidget {
  final M3eNavigationDestination destination;
  final bool selected;
  final bool animationsEnabled;
  final double cornerRadius;

  const _M3eNavigationDestination({
    required this.destination,
    required this.selected,
    required this.animationsEnabled,
    required this.cornerRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      selected: selected,
      button: true,
      label: destination.label,
      onTap: destination.onTap,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: destination.onTap,
          borderRadius: BorderRadius.circular(cornerRadius),
          child: AnimatedContainer(
            key: selected ? const ValueKey('m3e-navigation-selected-pill') : null,
            duration: animationsEnabled ? M3eTokens.standardMotion : Duration.zero,
            curve: M3eTokens.expressiveCurve,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: animationsEnabled ? M3eTokens.shortMotion : Duration.zero,
                  child: Icon(
                    destination.icon,
                    key: ValueKey(selected),
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    size: 25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class M3eTonalActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const M3eTonalActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 1,
        shape: const StadiumBorder(),
      ),
    );
  }
}
