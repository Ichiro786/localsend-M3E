import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/pages/device_details_page.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/selected_files_page.dart';
import 'package:localsend_app/pages/tabs/send_tab_vm.dart';
import 'package:localsend_app/pages/troubleshoot_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/file_transfer_provider.dart';
import 'package:localsend_app/provider/network/nearby_devices_provider.dart';
import 'package:localsend_app/provider/network/scan_facade.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/favorites.dart';
import 'package:localsend_app/util/native/file_picker.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_icon_button.dart';
import 'package:localsend_app/widget/dialogs/add_file_dialog.dart';
import 'package:localsend_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:localsend_app/widget/file_thumbnail.dart';
import 'package:localsend_app/widget/list_tile/device_list_tile.dart';
import 'package:localsend_app/widget/list_tile/device_placeholder_list_tile.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/opacity_slideshow.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/util/file_size_helper.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

const _horizontalPadding = 15.0;
final pickerOptions = FilePickerOption.getOptionsForPlatform();

class _SelectionGrid extends StatelessWidget {
  final Future<void> Function(FilePickerOption option) onSelect;

  const _SelectionGrid({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final animationsEnabled = context.watch(animationProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= (textScale > 1.3 ? 520 : 330) ? 3 : 2;
        final baseExtent = columns == 3 ? 136.0 : 152.0;
        final designExtent = baseExtent + (textScale > 1 ? (textScale - 1) * 28 : 0);
        final crossAxisSpacing = M3eTokens.standardGap;
        final cardWidth = (constraints.maxWidth - crossAxisSpacing * (columns - 1)) / columns;
        final tileExtent = pickerOptions.fold<double>(designExtent, (extent, option) {
          final requiredExtent = M3eSelectionCard.requiredHeightForLabel(
            context: context,
            label: option.label,
            cardWidth: cardWidth,
          );
          return requiredExtent > extent ? requiredExtent : extent;
        });
        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pickerOptions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: tileExtent,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: M3eTokens.standardGap,
          ),
          itemBuilder: (context, index) {
            final option = pickerOptions[index];
            return M3eSelectionCard(
              key: ValueKey(option),
              animationsEnabled: animationsEnabled,
              icon: option.icon,
              label: option.label,
              onTap: () => onSelect(option),
            );
          },
        );
      },
    );
  }
}

class SendTab extends StatelessWidget {
  final Future<void> Function(FilePickerOption option)? onPickerOption;

  const SendTab({this.onPickerOption, super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(SendTabInitAction(context)), // ignore: discarded_futures
      builder: (context, vm) {
        final ref = context.ref;
        return ResponsiveListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.sendTab.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: M3eTokens.compactGap),
                        Text(
                          t.sendTab.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: M3eTokens.standardGap),
                  M3eIconButton(
                    tooltip: t.receiveHistoryPage.title,
                    icon: Icons.history,
                    onPressed: () async => context.push(() => const ReceiveHistoryPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (vm.selectedFiles.isEmpty) ...[
              _SelectionGrid(
                onSelect: (option) async {
                  if (onPickerOption != null) {
                    await onPickerOption!(option);
                    return;
                  }
                  await ref.global.dispatchAsync(
                    PickFileAction(
                      option: option,
                      context: context,
                    ),
                  );
                },
              ),
              const SizedBox(height: M3eTokens.sectionGap),
            ] else ...[
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.88),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 18, top: 12, bottom: 15, end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(t.sendTab.selection.title, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          CustomIconButton(
                            onPressed: () => ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction()),
                            child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 5),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(t.sendTab.selection.files(files: vm.selectedFiles.length)),
                      Text(t.sendTab.selection.size(size: vm.selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: defaultThumbnailSize,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: vm.selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = vm.selectedFiles[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: SmartFileThumbnail.fromCrossFile(file),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: M3eTokens.compactGap,
                        runSpacing: M3eTokens.compactGap,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                            ),
                            onPressed: () async {
                              await context.push(() => const SelectedFilesPage());
                            },
                            child: Text(t.general.edit),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                            onPressed: () async {
                              if (pickerOptions.length == 1) {
                                // open directly
                                await ref.global.dispatchAsync(
                                  PickFileAction(
                                    option: pickerOptions.first,
                                    context: context,
                                  ),
                                );
                                return;
                              }
                              await AddFileDialog.open(
                                context: context,
                                options: pickerOptions,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text(t.general.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.sendTab.nearbyDevices, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: M3eTokens.compactGap / 2),
                            Text(
                              t.sendTab.devicesAvailable(count: vm.nearbyDevices.length),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: M3eTokens.compactGap),
                      _ScanButton(ips: vm.localIps),
                    ],
                  ),
                  const SizedBox(height: M3eTokens.compactGap),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SecondarySendAction(
                          tooltip: t.sendTab.manualSending,
                          icon: Icons.ads_click,
                          onPressed: () async => vm.onTapAddress(context),
                        ),
                        const SizedBox(width: M3eTokens.compactGap),
                        _SecondarySendAction(
                          tooltip: t.dialogs.favoriteDialog.title,
                          icon: Icons.favorite,
                          onPressed: () async => vm.onTapFavorite(context),
                        ),
                        const SizedBox(width: M3eTokens.compactGap),
                        _SendModeButton(
                          onSelect: (mode) async => vm.onTapSendMode(context, mode),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: M3eTokens.standardGap),
            if (vm.nearbyDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10, left: _horizontalPadding, right: _horizontalPadding),
                child: Opacity(
                  opacity: 0.3,
                  child: DevicePlaceholderListTile(),
                ),
              ),
            ...vm.nearbyDevices.map((device) {
              final favoriteEntry = vm.favoriteDevices.findDevice(device);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10, left: _horizontalPadding, right: _horizontalPadding),
                child: Hero(
                  tag: 'device-${device.ip}',
                  child: vm.sendMode == SendMode.multiple
                      ? _MultiSendDeviceListTile(
                          device: device,
                          isFavorite: favoriteEntry != null,
                          nameOverride: favoriteEntry?.alias,
                          vm: vm,
                        )
                      : DeviceListTile(
                          device: device,
                          isFavorite: favoriteEntry != null,
                          nameOverride: favoriteEntry?.alias,
                          onDetailsTap: () async => await context.push(() => DeviceDetailsPage(device: device)),
                          onTap: () async => await vm.onTapDevice(context, device),
                        ),
                ),
              );
            }),
            const SizedBox(height: 18),
            Semantics(
              button: true,
              label: t.troubleshootPage.title,
              child: Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.62),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    await context.push(() => const TroubleshootPage());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Consumer(
                      builder: (context, ref) {
                        final animations = ref.watch(animationProvider);
                        final motionAllowed = animations && !MediaQuery.of(context).disableAnimations;
                        return OpacitySlideshow(
                          durationMillis: 6000,
                          running: motionAllowed,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                                const SizedBox(height: M3eTokens.compactGap),
                                Text(
                                  t.troubleshootPage.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: M3eTokens.compactGap),
                                Text(
                                  t.sendTab.help,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            if (checkPlatformCanReceiveShareIntent())
                              Text(
                                t.sendTab.shareIntentInfo,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

/// A button that opens a popup menu to select [T].
/// This is used for the scan button and the send mode button.
class _CircularPopupButton<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;
  final bool emphasized;

  const _CircularPopupButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
    required this.child,
    this.emphasized = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: Material(
        type: MaterialType.transparency,
        child: DividerTheme(
          data: DividerThemeData(color: scheme.outlineVariant),
          child: Semantics(
            button: true,
            label: tooltip,
            child: PopupMenuButton(
              offset: const Offset(0, 40),
              onSelected: onSelected,
              tooltip: tooltip,
              itemBuilder: itemBuilder,
              child: SizedBox.square(
                dimension: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: emphasized ? scheme.primaryContainer.withValues(alpha: 0.86) : scheme.surfaceContainerLow.withValues(alpha: 0.58),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: emphasized ? scheme.primary.withValues(alpha: 0.32) : scheme.outlineVariant.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(color: foreground),
                      child: child,
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

/// The scan button that uses [_CircularPopupButton].
class _ScanButton extends StatelessWidget {
  final List<String> ips;

  const _ScanButton({
    required this.ips,
  });

  @override
  Widget build(BuildContext context) {
    final (scanningFavorites, scanningIps) = context.ref.watch(nearbyDevicesProvider.select((s) => (s.runningFavoriteScan, s.runningIps)));
    final animations = context.ref.watch(animationProvider);

    final motionAllowed = animations && !MediaQuery.of(context).disableAnimations;
    final spinning = (scanningFavorites || scanningIps.isNotEmpty) && motionAllowed;
    final iconColor = !motionAllowed && scanningIps.isNotEmpty ? Theme.of(context).colorScheme.warning : null;

    if (ips.length <= StartSmartScan.maxInterfaces) {
      return RotatingWidget(
        duration: const Duration(seconds: 2),
        spinning: spinning,
        reverse: true,
        child: M3eIconButton(
          tooltip: t.sendTab.scan,
          onPressed: () async {
            context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
            await context.global.dispatchAsync(StartSmartScan());
          },
          icon: Icons.sync,
          selected: true,
        ),
      );
    }

    return _CircularPopupButton(
      tooltip: t.sendTab.scan,
      emphasized: true,
      onSelected: (ip) async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
      },
      itemBuilder: (_) {
        return [
          ...ips.map(
            (ip) => PopupMenuItem(
              value: ip,
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RotatingSyncIcon(ip),
                  const SizedBox(width: 10),
                  Flexible(child: Text(ip)),
                ],
              ),
            ),
          ),
        ];
      },
      child: RotatingWidget(
        duration: const Duration(seconds: 2),
        spinning: spinning,
        reverse: true,
        child: Icon(Icons.sync, color: iconColor),
      ),
    );
  }
}

/// A separate widget, so it gets the latest data from provider.
class _RotatingSyncIcon extends StatelessWidget {
  final String ip;

  const _RotatingSyncIcon(this.ip);

  @override
  Widget build(BuildContext context) {
    final scanningIps = context.ref.watch(nearbyDevicesProvider.select((s) => s.runningIps));
    final animations = context.ref.watch(animationProvider);
    final motionAllowed = animations && !MediaQuery.of(context).disableAnimations;
    return RotatingWidget(
      duration: const Duration(seconds: 2),
      spinning: motionAllowed && scanningIps.contains(ip),
      reverse: true,
      child: const Icon(Icons.sync),
    );
  }
}

class _SecondarySendAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondarySendAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return M3eIconButton(icon: icon, onPressed: onPressed, tooltip: tooltip);
  }
}

class _SendModeButton extends StatelessWidget {
  final void Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CircularPopupButton<int>(
      tooltip: t.sendTab.sendMode,
      onSelected: (mode) async {
        switch (mode) {
          case 0:
            onSelect(SendMode.single);
            break;
          case 1:
            onSelect(SendMode.multiple);
            break;
          case 2:
            onSelect(SendMode.link);
            break;
          case -1:
            await showDialog(context: context, builder: (_) => const SendModeHelpDialog());
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.single,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t.sendTab.sendModes.single,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.multiple,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t.sendTab.sendModes.multiple,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Icon(Icons.check_circle),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t.sendTab.sendModes.link,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.help),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t.sendTab.sendModeHelp,
                ),
              ),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.settings, size: 22),
    );
  }
}

/// An advanced list tile which shows the progress of the file transfer.
class _MultiSendDeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final SendTabVm vm;

  const _MultiSendDeviceListTile({
    required this.device,
    required this.isFavorite,
    required this.nameOverride,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final session = ref.watch(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
    final String? info;
    final double? progress;
    if (session != null) {
      final files = session.files.values.where((f) => f.token != null);
      final transferNotifier = ref.watch(fileTransferProvider);
      final currBytes = files.fold<int>(
        0,
        (prev, curr) => prev + ((transferNotifier.getProgress(sessionId: session.sessionId, fileId: curr.file.id) * curr.file.size).round()),
      );
      final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
      progress = totalBytes == 0 ? 0 : currBytes / totalBytes;
      info = session.hashedFileCount < session.files.length
          ? t.sendPage.calculatingChecksum(curr: session.hashedFileCount, n: session.files.length)
          : session.status.humanString;
    } else {
      progress = null;
      info = null;
    }
    return DeviceListTile(
      device: device,
      info: info,
      progress: progress,
      isFavorite: isFavorite,
      nameOverride: nameOverride,
      onDetailsTap: () async => await context.push(() => DeviceDetailsPage(device: device)),
      onTap: () async => await vm.onTapDeviceMultiSend(context, device),
    );
  }
}

extension on SessionStatus {
  String? get humanString {
    switch (this) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.sending:
        return null;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
    }
  }
}
