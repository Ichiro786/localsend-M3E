import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';

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

  const M3eSectionCard({
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(22, 22, 22, 10),
    this.leading,
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
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class M3eSelectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  const M3eSelectionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = emphasized ? scheme.primaryContainer.withValues(alpha: 0.78) : scheme.surfaceContainerLow.withValues(alpha: 0.84);
    final foreground = emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: emphasized ? 0.3 : 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Icon(icon, size: 30, color: emphasized ? foreground : scheme.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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

class M3eFloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final List<M3eNavigationDestination> destinations;

  const M3eFloatingNavigationBar({
    required this.selectedIndex,
    required this.destinations,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: M3eTokens.elevatedSurface(scheme),
          borderRadius: BorderRadius.circular(M3eTokens.navigationRadius),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _M3eNavigationDestination(
                    destination: destinations[index],
                    selected: index == selectedIndex,
                  ),
                ),
            ],
          ),
        ),
      ),
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

  const _M3eNavigationDestination({required this.destination, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: destination.onTap,
          borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
          child: AnimatedContainer(
            duration: M3eTokens.standardMotion,
            curve: M3eTokens.expressiveCurve,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
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
                  maxLines: 1,
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
