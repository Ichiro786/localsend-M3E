import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/widget/custom_progress_bar.dart';
import 'package:localsend_app/widget/device_bage.dart';
import 'package:localsend_isolates/model/device.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  /// If not null, this name is used instead of [Device.alias].
  /// This is the case when the device is marked as favorite.
  final String? nameOverride;

  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = scheme.primaryContainer.withValues(alpha: 0.72);
    final title = nameOverride ?? device.alias;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow.withValues(alpha: 0.88),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(device.deviceType.icon, size: 42, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isFavorite) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.favorite, size: 18, color: scheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (info != null)
                      Text(
                        info!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    else if (progress != null)
                      CustomProgressBar(progress: progress!)
                    else
                      Wrap(
                        runSpacing: 6,
                        spacing: 6,
                        children: [
                          DeviceBadge(
                            backgroundColor: badgeColor,
                            foregroundColor: scheme.onPrimaryContainer,
                            label: device.ip != null ? 'HTTP' : 'WebRTC',
                          ),
                          if (device.deviceModel != null)
                            DeviceBadge(
                              backgroundColor: badgeColor,
                              foregroundColor: scheme.onPrimaryContainer,
                              label: device.deviceModel!,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (onDetailsTap != null)
                IconButton(
                  tooltip: t.deviceDetailsPage.title,
                  onPressed: onDetailsTap,
                  icon: const Icon(Icons.chevron_right),
                  color: scheme.onSurfaceVariant,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
