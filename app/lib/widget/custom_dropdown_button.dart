import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/config/theme.dart';

/// A [DropdownButton] with a custom theme.
/// Currently, there is no easy way to apply color and border radius to all [DropdownButton].
class CustomDropdownButton<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T>? onChanged;
  final bool expanded;

  const CustomDropdownButton({
    required this.value,
    required this.items,
    this.onChanged,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.inputDecorationTheme.fillColor ?? scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: theme.inputDecorationTheme.borderRadius,
        side: M3eTokens.outline(scheme, opacity: 0.72),
      ),
      clipBehavior: Clip.antiAlias,
      child: DropdownButton<T>(
        value: value,
        isExpanded: expanded,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        underline: Container(),
        borderRadius: Theme.of(context).inputDecorationTheme.borderRadius,
        items: items,
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) {
                  onChanged!(value);
                }
              },
      ),
    );
  }
}
