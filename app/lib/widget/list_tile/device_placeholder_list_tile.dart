import 'package:flutter/material.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';

class DevicePlaceholderListTile extends StatelessWidget {
  const DevicePlaceholderListTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final animations = context.ref.watch(animationProvider);
    final placeholder = scheme.onSurface.withValues(alpha: 0.12);

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow.withValues(alpha: 0.78),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OpacitySlideshow(
                  durationMillis: 3000,
                  running: animations,
                  children: [
                    ...DeviceType.values.map((d) => Icon(d.icon, size: 42, color: scheme.onPrimaryContainer)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 14,
                    decoration: BoxDecoration(color: placeholder, borderRadius: BorderRadius.circular(99)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 210,
                    height: 14,
                    decoration: BoxDecoration(color: placeholder, borderRadius: BorderRadius.circular(99)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
