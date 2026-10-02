import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/pages/about/about_page.dart';
import 'package:localsend_app/pages/changelog_page.dart';
import 'package:localsend_app/pages/donation/donation_page.dart';
import 'package:localsend_app/pages/settings/network_interfaces_page.dart';
import 'package:localsend_app/pages/tabs/settings_tab_controller.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/provider/version_provider.dart';
import 'package:localsend_app/util/alias_generator.dart';
import 'package:localsend_app/util/device_type_ext.dart';
import 'package:localsend_app/util/i18n.dart';
import 'package:localsend_app/util/native/macos_channel.dart';
import 'package:localsend_app/util/native/pick_directory_path.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/widget/custom_dropdown_button.dart';
import 'package:localsend_app/widget/dialogs/encryption_disabled_notice.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/quick_save_from_favorites_notice.dart';
import 'package:localsend_app/widget/dialogs/quick_save_notice.dart';
import 'package:localsend_app/widget/dialogs/text_field_tv.dart';
import 'package:localsend_app/widget/dialogs/text_field_with_actions.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => settingsTabControllerProvider,
      builder: (context, vm) {
        final ref = context.ref;
        final motionAllowed = ref.watch(animationProvider) && !MediaQuery.disableAnimationsOf(context);
        final settingsControlWidth = MediaQuery.sizeOf(context).width >= 600 ? 240.0 : 132.0;
        return ResponsiveListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 48),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsTab.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: M3eTokens.compactGap / 2),
                  Text(
                    t.settingsTab.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SettingsSection(
              title: t.settingsTab.general.title,
              supportingText: t.settingsTab.general.subtitle,
              children: [
                M3eSettingsRow(
                  icon: Icons.dark_mode_outlined,
                  title: t.settingsTab.general.brightness,
                  supportingText: t.settingsTab.general.brightnessDescription,
                  semanticLabel: t.settingsTab.general.brightness,
                  preferredTrailingWidth: settingsControlWidth,
                  trailing: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: settingsControlWidth),
                    child: CustomDropdownButton<ThemeMode>(
                      value: vm.settings.theme,
                      expanded: true,
                      items: vm.themeModes.map((theme) {
                        return DropdownMenuItem(
                          value: theme,
                          alignment: Alignment.center,
                          child: Text(
                            theme.humanName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (theme) => vm.onChangeTheme(context, theme),
                    ),
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.palette_outlined,
                  title: t.settingsTab.general.color,
                  supportingText: t.settingsTab.general.colorDescription,
                  semanticLabel: t.settingsTab.general.color,
                  preferredTrailingWidth: settingsControlWidth,
                  trailing: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: settingsControlWidth),
                    child: CustomDropdownButton<ColorMode>(
                      value: vm.settings.colorMode,
                      expanded: true,
                      items: vm.colorModes.map((colorMode) {
                        return DropdownMenuItem(
                          value: colorMode,
                          alignment: Alignment.center,
                          child: Text(
                            colorMode.humanName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (colorMode) => vm.onChangeColorMode(context, colorMode),
                    ),
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.language,
                  title: t.settingsTab.general.language,
                  supportingText: t.settingsTab.general.languageDescription,
                  semanticLabel:
                      '${t.settingsTab.general.language}, ${vm.settings.locale?.getLocaleName() ?? t.settingsTab.general.languageOptions.system}',
                  trailing: _settingsActionValue(
                    context,
                    vm.settings.locale?.getLocaleName() ?? t.settingsTab.general.languageOptions.system,
                  ),
                  onTap: () => vm.onTapLanguage(context),
                ),
                if (checkPlatformIsDesktop()) ...[
                  /// Wayland does window position handling, so there's no need for it. See [https://github.com/localsend/localsend/issues/544]
                  if (vm.advanced && checkPlatformIsNotWaylandDesktop())
                    M3eSettingsRow(
                      icon: Icons.window_outlined,
                      title: defaultTargetPlatform == TargetPlatform.windows
                          ? t.settingsTab.general.saveWindowPlacementWindows
                          : t.settingsTab.general.saveWindowPlacement,
                      supportingText: t.settingsTab.general.saveWindowPlacementDescription,
                      semanticLabel: defaultTargetPlatform == TargetPlatform.windows
                          ? t.settingsTab.general.saveWindowPlacementWindows
                          : t.settingsTab.general.saveWindowPlacement,
                      trailing: M3eExpressiveSwitch(
                        value: vm.settings.saveWindowPlacement,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setSaveWindowPlacement(b);
                        },
                        semanticLabel:
                            '${defaultTargetPlatform == TargetPlatform.windows ? t.settingsTab.general.saveWindowPlacementWindows : t.settingsTab.general.saveWindowPlacement}, ${vm.settings.saveWindowPlacement ? t.general.on : t.general.off}',
                      ),
                    ),
                  if (checkPlatformHasTray()) ...[
                    M3eSettingsRow(
                      icon: Icons.vertical_align_bottom,
                      title: t.settingsTab.general.minimizeToTray,
                      supportingText: t.settingsTab.general.minimizeToTrayDescription,
                      semanticLabel: t.settingsTab.general.minimizeToTray,
                      trailing: M3eExpressiveSwitch(
                        value: vm.settings.minimizeToTray,
                        onChanged: (b) async {
                          await ref.notifier(settingsProvider).setMinimizeToTray(b);
                        },
                        semanticLabel: '${t.settingsTab.general.minimizeToTray}, ${vm.settings.minimizeToTray ? t.general.on : t.general.off}',
                      ),
                    ),
                  ],
                  if (checkPlatformIsDesktop()) ...[
                    M3eSettingsRow(
                      icon: Icons.power_settings_new,
                      title: t.settingsTab.general.launchAtStartup,
                      supportingText: t.settingsTab.general.launchAtStartupDescription,
                      semanticLabel: t.settingsTab.general.launchAtStartup,
                      trailing: M3eExpressiveSwitch(
                        value: vm.autoStart,
                        onChanged: (_) => vm.onToggleAutoStart(context),
                        semanticLabel: '${t.settingsTab.general.launchAtStartup}, ${vm.autoStart ? t.general.on : t.general.off}',
                      ),
                    ),
                    Visibility(
                      visible: vm.autoStart,
                      maintainAnimation: true,
                      maintainState: true,
                      child: AnimatedOpacity(
                        opacity: vm.autoStart ? 1.0 : 0.0,
                        duration: motionAllowed ? const Duration(milliseconds: 500) : Duration.zero,
                        child: M3eSettingsRow(
                          icon: Icons.minimize,
                          title: t.settingsTab.general.launchMinimized,
                          supportingText: t.settingsTab.general.launchMinimizedDescription,
                          semanticLabel: t.settingsTab.general.launchMinimized,
                          trailing: M3eExpressiveSwitch(
                            value: vm.autoStartLaunchHidden,
                            onChanged: (_) => vm.onToggleAutoStartLaunchHidden(context),
                            semanticLabel: '${t.settingsTab.general.launchMinimized}, ${vm.autoStartLaunchHidden ? t.general.on : t.general.off}',
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (vm.advanced && checkPlatform([TargetPlatform.windows])) ...[
                    M3eSettingsRow(
                      icon: Icons.more_horiz,
                      title: t.settingsTab.general.showInContextMenu,
                      supportingText: t.settingsTab.general.showInContextMenuDescription,
                      semanticLabel: t.settingsTab.general.showInContextMenu,
                      trailing: M3eExpressiveSwitch(
                        value: vm.showInContextMenu,
                        onChanged: (_) => vm.onToggleShowInContextMenu(context),
                        semanticLabel: '${t.settingsTab.general.showInContextMenu}, ${vm.showInContextMenu ? t.general.on : t.general.off}',
                      ),
                    ),
                  ],
                ],
                M3eSettingsRow(
                  icon: Icons.animation_outlined,
                  title: t.settingsTab.general.animations,
                  supportingText: t.settingsTab.general.animationsDescription,
                  semanticLabel: t.settingsTab.general.animations,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.enableAnimations,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setEnableAnimations(b);
                    },
                    semanticLabel: '${t.settingsTab.general.animations}, ${vm.settings.enableAnimations ? t.general.on : t.general.off}',
                  ),
                ),
              ],
            ),
            _SettingsSection(
              title: t.settingsTab.receive.title,
              supportingText: t.settingsTab.receive.subtitle,
              children: [
                M3eSettingsRow(
                  icon: Icons.download_outlined,
                  title: t.settingsTab.receive.quickSave,
                  supportingText: t.settingsTab.receive.quickSaveDescription,
                  semanticLabel: t.settingsTab.receive.quickSave,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.quickSave,
                    onChanged: (b) async {
                      final old = vm.settings.quickSave;
                      await ref.notifier(settingsProvider).setQuickSave(b);
                      if (b) {
                        await ref.notifier(settingsProvider).setQuickSaveFromFavorites(false);
                      }
                      if (!old && b && context.mounted) {
                        await QuickSaveNotice.open(context);
                      }
                    },
                    semanticLabel: '${t.settingsTab.receive.quickSave}, ${vm.settings.quickSave ? t.general.on : t.general.off}',
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.favorite_border,
                  title: t.settingsTab.receive.quickSaveFromFavorites,
                  supportingText: t.settingsTab.receive.quickSaveFromFavoritesDescription,
                  semanticLabel: t.settingsTab.receive.quickSaveFromFavorites,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.quickSaveFromFavorites,
                    onChanged: (b) async {
                      final old = vm.settings.quickSaveFromFavorites;
                      await ref.notifier(settingsProvider).setQuickSaveFromFavorites(b);
                      if (b) {
                        await ref.notifier(settingsProvider).setQuickSave(false);
                      }
                      if (!old && b && context.mounted) {
                        await QuickSaveFromFavoritesNotice.open(context);
                      }
                    },
                    semanticLabel:
                        '${t.settingsTab.receive.quickSaveFromFavorites}, ${vm.settings.quickSaveFromFavorites ? t.general.on : t.general.off}',
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.lock_outline,
                  title: t.settingsTab.receive.requirePin,
                  supportingText: t.settingsTab.receive.requirePinDescription,
                  semanticLabel: t.settingsTab.receive.requirePin,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.receivePin != null,
                    onChanged: (b) async {
                      final currentPIN = vm.settings.receivePin;
                      if (currentPIN != null) {
                        await ref.notifier(settingsProvider).setReceivePin(null);
                      } else {
                        final String? newPin = await showDialog<String>(
                          context: context,
                          builder: (_) => const PinDialog(
                            obscureText: false,
                            generateRandom: false,
                          ),
                        );

                        if (newPin != null && newPin.isNotEmpty) {
                          await ref.notifier(settingsProvider).setReceivePin(newPin);
                        }
                      }

                      // The pin is enforced by the Rust server, so it needs a restart.
                      if (ref.read(serverProvider) != null) {
                        await ref.notifier(serverProvider).restartServerFromSettings();
                      }
                    },
                    semanticLabel: '${t.settingsTab.receive.requirePin}, ${vm.settings.receivePin == null ? t.general.off : t.general.on}',
                  ),
                ),
                if (checkPlatformWithFileSystem())
                  M3eSettingsRow(
                    icon: Icons.folder_open_outlined,
                    title: t.settingsTab.receive.destination,
                    supportingText: t.settingsTab.receive.destinationDescription,
                    semanticLabel: '${t.settingsTab.receive.destination}, ${vm.settings.destination ?? t.settingsTab.receive.downloads}',
                    trailing: _settingsActionValue(
                      context,
                      vm.settings.destination ?? t.settingsTab.receive.downloads,
                    ),
                    onTap: () async {
                      if (vm.settings.destination != null) {
                        await ref.notifier(settingsProvider).setDestination(null);
                        if (defaultTargetPlatform == TargetPlatform.macOS) {
                          await removeExistingDestinationAccess();
                        }
                        return;
                      }

                      final directory = await pickDirectoryPath();
                      if (directory != null) {
                        if (defaultTargetPlatform == TargetPlatform.macOS) {
                          await persistDestinationFolderAccess(directory);
                        }
                        await ref.notifier(settingsProvider).setDestination(directory);
                      }
                    },
                  ),
                if (checkPlatformWithGallery())
                  M3eSettingsRow(
                    icon: Icons.photo_library_outlined,
                    title: t.settingsTab.receive.saveToGallery,
                    supportingText: t.settingsTab.receive.saveToGalleryDescription,
                    semanticLabel: t.settingsTab.receive.saveToGallery,
                    trailing: M3eExpressiveSwitch(
                      value: vm.settings.saveToGallery,
                      onChanged: (b) async {
                        await ref.notifier(settingsProvider).setSaveToGallery(b);
                      },
                      semanticLabel: '${t.settingsTab.receive.saveToGallery}, ${vm.settings.saveToGallery ? t.general.on : t.general.off}',
                    ),
                  ),
                M3eSettingsRow(
                  icon: Icons.done_all,
                  title: t.settingsTab.receive.autoFinish,
                  supportingText: t.settingsTab.receive.autoFinishDescription,
                  semanticLabel: t.settingsTab.receive.autoFinish,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.autoFinish,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setAutoFinish(b);
                    },
                    semanticLabel: '${t.settingsTab.receive.autoFinish}, ${vm.settings.autoFinish ? t.general.on : t.general.off}',
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.history,
                  title: t.settingsTab.receive.saveToHistory,
                  supportingText: t.settingsTab.receive.saveToHistoryDescription,
                  semanticLabel: t.settingsTab.receive.saveToHistory,
                  trailing: M3eExpressiveSwitch(
                    value: vm.settings.saveToHistory,
                    onChanged: (b) async {
                      await ref.notifier(settingsProvider).setSaveToHistory(b);
                    },
                    semanticLabel: '${t.settingsTab.receive.saveToHistory}, ${vm.settings.saveToHistory ? t.general.on : t.general.off}',
                  ),
                ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.verified_outlined,
                    title: t.settingsTab.receive.verifyChecksums,
                    supportingText: t.settingsTab.receive.verifyChecksumsDescription,
                    semanticLabel: t.settingsTab.receive.verifyChecksums,
                    trailing: M3eExpressiveSwitch(
                      value: vm.settings.verifyChecksums,
                      onChanged: (b) async {
                        await ref.notifier(settingsProvider).setVerifyChecksums(b);

                        // The checksums are verified by the Rust server, so it needs a restart.
                        if (ref.read(serverProvider) != null) {
                          await ref.notifier(serverProvider).restartServerFromSettings();
                        }
                      },
                      semanticLabel: '${t.settingsTab.receive.verifyChecksums}, ${vm.settings.verifyChecksums ? t.general.on : t.general.off}',
                    ),
                  ),
              ],
            ),
            if (vm.advanced)
              _SettingsSection(
                title: t.settingsTab.send.title,
                supportingText: t.settingsTab.send.subtitle,
                children: [
                  M3eSettingsRow(
                    icon: Icons.link,
                    title: t.settingsTab.send.shareViaLinkAutoAccept,
                    supportingText: t.settingsTab.send.shareViaLinkAutoAcceptDescription,
                    semanticLabel: t.settingsTab.send.shareViaLinkAutoAccept,
                    trailing: M3eExpressiveSwitch(
                      value: vm.settings.shareViaLinkAutoAccept,
                      onChanged: (b) async {
                        await ref.notifier(settingsProvider).setShareViaLinkAutoAccept(b);
                      },
                      semanticLabel:
                          '${t.settingsTab.send.shareViaLinkAutoAccept}, ${vm.settings.shareViaLinkAutoAccept ? t.general.on : t.general.off}',
                    ),
                  ),
                  M3eSettingsRow(
                    icon: Icons.fingerprint,
                    title: t.settingsTab.send.createChecksums,
                    supportingText: t.settingsTab.send.createChecksumsDescription,
                    semanticLabel: t.settingsTab.send.createChecksums,
                    trailing: M3eExpressiveSwitch(
                      value: vm.settings.createChecksums,
                      onChanged: (b) async {
                        await ref.notifier(settingsProvider).setCreateChecksums(b);
                      },
                      semanticLabel: '${t.settingsTab.send.createChecksums}, ${vm.settings.createChecksums ? t.general.on : t.general.off}',
                    ),
                  ),
                ],
              ),
            _SettingsSection(
              title: t.settingsTab.network.title,
              supportingText: t.settingsTab.network.subtitle,
              children: [
                M3eMotionAwareCrossFade(
                  motionAllowed: motionAllowed,
                  crossFadeState:
                      vm.serverState != null &&
                          (vm.serverState!.alias != vm.settings.alias ||
                              vm.serverState!.port != vm.settings.port ||
                              vm.serverState!.https != vm.settings.https)
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topLeft,
                  firstChild: Container(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      t.settingsTab.network.needRestart,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.warning,
                      ),
                    ),
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.dns_outlined,
                  title: '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                  supportingText: t.settingsTab.network.serverDescription,
                  semanticLabel: '${t.settingsTab.network.server}${vm.serverState == null ? ' (${t.general.offline})' : ''}',
                  preferredTrailingWidth: 96,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vm.serverState == null)
                        Tooltip(
                          message: t.general.start,
                          child: IconButton(
                            color: Theme.of(context).colorScheme.onSurface,
                            iconSize: 24,
                            onPressed: () => vm.onTapStartServer(context),
                            icon: const Icon(Icons.play_arrow),
                          ),
                        )
                      else
                        Tooltip(
                          message: t.general.restart,
                          child: IconButton(
                            color: Theme.of(context).colorScheme.onSurface,
                            iconSize: 24,
                            onPressed: () => vm.onTapRestartServer(context),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      Tooltip(
                        message: t.general.stop,
                        child: IconButton(
                          color: Theme.of(context).colorScheme.onSurface,
                          iconSize: 24,
                          onPressed: vm.serverState == null ? null : vm.onTapStopServer,
                          icon: const Icon(Icons.stop),
                        ),
                      ),
                    ],
                  ),
                ),
                M3eSettingsRow(
                  icon: Icons.badge_outlined,
                  title: t.settingsTab.network.alias,
                  supportingText: t.settingsTab.network.aliasDescription,
                  semanticLabel: t.settingsTab.network.alias,
                  preferredTrailingWidth: settingsControlWidth,
                  trailing: SizedBox(
                    width: settingsControlWidth,
                    child: TextFieldWithActions(
                      name: t.settingsTab.network.alias,
                      controller: vm.aliasController,
                      onChanged: (s) async {
                        await ref.notifier(settingsProvider).setAlias(s);
                      },
                      actions: [
                        Tooltip(
                          message: t.settingsTab.network.generateRandomAlias,
                          child: IconButton(
                            onPressed: () async {
                              // Generates random alias
                              final newAlias = generateRandomAlias();

                              // Update the TextField with the new alias
                              vm.aliasController.text = newAlias;

                              // Persist the new alias using the settingsProvider
                              await ref.notifier(settingsProvider).setAlias(newAlias);
                            },
                            icon: const Icon(Icons.casino),
                          ),
                        ),
                        Tooltip(
                          message: t.settingsTab.network.useSystemName,
                          child: IconButton(
                            onPressed: () async {
                              final String newAlias;
                              if (Platform.isMacOS) {
                                final result = await Process.run('scutil', [
                                  '--get',
                                  'ComputerName',
                                ]);
                                newAlias = result.stdout.toString().trim();
                              } else {
                                newAlias = Platform.localHostname;
                              }

                              vm.aliasController.text = newAlias;
                              await ref.notifier(settingsProvider).setAlias(newAlias);
                            },
                            icon: const Icon(Icons.desktop_windows_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.devices_outlined,
                    title: t.settingsTab.network.deviceType,
                    supportingText: t.settingsTab.network.deviceTypeDescription,
                    semanticLabel: t.settingsTab.network.deviceType,
                    trailing: CustomDropdownButton<DeviceType>(
                      value: vm.deviceInfo.deviceType,
                      expanded: false,
                      items: DeviceType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          alignment: Alignment.center,
                          child: Icon(type.icon),
                        );
                      }).toList(),
                      onChanged: (type) async {
                        await ref.notifier(settingsProvider).setDeviceType(type);
                      },
                    ),
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.smartphone,
                    title: t.settingsTab.network.deviceModel,
                    supportingText: t.settingsTab.network.deviceModelDescription,
                    semanticLabel: t.settingsTab.network.deviceModel,
                    preferredTrailingWidth: settingsControlWidth,
                    trailing: SizedBox(
                      width: settingsControlWidth,
                      child: TextFieldTv(
                        name: t.settingsTab.network.deviceModel,
                        controller: vm.deviceModelController,
                        onChanged: (s) async {
                          await ref.notifier(settingsProvider).setDeviceModel(s);
                        },
                      ),
                    ),
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.numbers,
                    title: t.settingsTab.network.port,
                    supportingText: t.settingsTab.network.portDescription,
                    semanticLabel: t.settingsTab.network.port,
                    preferredTrailingWidth: settingsControlWidth,
                    trailing: SizedBox(
                      width: settingsControlWidth,
                      child: TextFieldTv(
                        name: t.settingsTab.network.port,
                        controller: vm.portController,
                        onChanged: (s) async {
                          final port = int.tryParse(s);
                          if (port != null) {
                            await ref.notifier(settingsProvider).setPort(port);
                          }
                        },
                      ),
                    ),
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.wifi_tethering_outlined,
                    title: t.settingsTab.network.network,
                    supportingText: t.settingsTab.network.networkDescription,
                    semanticLabel: t.settingsTab.network.network,
                    trailing: _settingsActionValue(
                      context,
                      switch (vm.settings.networkWhitelist != null || vm.settings.networkBlacklist != null) {
                        true => t.settingsTab.network.networkOptions.filtered,
                        false => t.settingsTab.network.networkOptions.all,
                      },
                    ),
                    onTap: () async {
                      await context.push(() => const NetworkInterfacesPage());
                    },
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.timer_outlined,
                    title: t.settingsTab.network.discoveryTimeout,
                    supportingText: t.settingsTab.network.discoveryTimeoutDescription,
                    semanticLabel: t.settingsTab.network.discoveryTimeout,
                    preferredTrailingWidth: settingsControlWidth,
                    trailing: SizedBox(
                      width: settingsControlWidth,
                      child: TextFieldTv(
                        name: t.settingsTab.network.discoveryTimeout,
                        controller: vm.timeoutController,
                        onChanged: (s) async {
                          final timeout = int.tryParse(s);
                          if (timeout != null) {
                            await ref.notifier(settingsProvider).setDiscoveryTimeout(timeout);
                          }
                        },
                      ),
                    ),
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.shield_outlined,
                    title: t.settingsTab.network.encryption,
                    supportingText: t.settingsTab.network.encryptionDescription,
                    semanticLabel: t.settingsTab.network.encryption,
                    trailing: M3eExpressiveSwitch(
                      value: vm.settings.https,
                      onChanged: (b) async {
                        final old = vm.settings.https;
                        await ref.notifier(settingsProvider).setHttps(b);
                        if (old && !b && context.mounted) {
                          await EncryptionDisabledNotice.open(context);
                        }
                      },
                      semanticLabel: '${t.settingsTab.network.encryption}, ${vm.settings.https ? t.general.on : t.general.off}',
                    ),
                  ),
                if (vm.advanced)
                  M3eSettingsRow(
                    icon: Icons.cell_tower_outlined,
                    title: t.settingsTab.network.multicastGroup,
                    supportingText: t.settingsTab.network.multicastGroupDescription,
                    semanticLabel: t.settingsTab.network.multicastGroup,
                    preferredTrailingWidth: settingsControlWidth,
                    trailing: SizedBox(
                      width: settingsControlWidth,
                      child: TextFieldTv(
                        name: t.settingsTab.network.multicastGroup,
                        controller: vm.multicastController,
                        onChanged: (s) async {
                          await ref.notifier(settingsProvider).setMulticastGroup(s);
                        },
                      ),
                    ),
                  ),
                M3eMotionAwareCrossFade(
                  motionAllowed: motionAllowed,
                  crossFadeState: vm.settings.port != defaultPort ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topLeft,
                  firstChild: Container(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      t.settingsTab.network.portWarning(
                        defaultPort: defaultPort,
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                M3eMotionAwareCrossFade(
                  motionAllowed: motionAllowed,
                  crossFadeState: vm.settings.multicastGroup != defaultMulticastGroup ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topLeft,
                  firstChild: Container(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      t.settingsTab.network.multicastGroupWarning(
                        defaultMulticast: defaultMulticastGroup,
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
            _SettingsSection(
              title: t.settingsTab.other.title,
              supportingText: t.settingsTab.other.subtitle,
              padding: const EdgeInsets.only(bottom: 0),
              children: [
                M3eSettingsRow(
                  icon: Icons.info_outline,
                  title: t.aboutPage.title,
                  supportingText: t.settingsTab.other.aboutDescription,
                  semanticLabel: t.aboutPage.title,
                  trailing: _settingsActionValue(context, t.general.open),
                  onTap: () async {
                    await context.push(() => const AboutPage());
                  },
                ),
                M3eSettingsRow(
                  icon: Icons.favorite_border,
                  title: t.settingsTab.other.support,
                  supportingText: t.settingsTab.other.supportDescription,
                  semanticLabel: t.settingsTab.other.support,
                  trailing: _settingsActionValue(
                    context,
                    t.settingsTab.other.donate,
                  ),
                  onTap: () async {
                    await context.push(() => const DonationPage());
                  },
                ),
                M3eSettingsRow(
                  icon: Icons.policy_outlined,
                  title: t.settingsTab.other.privacyPolicy,
                  supportingText: t.settingsTab.other.privacyPolicyDescription,
                  semanticLabel: t.settingsTab.other.privacyPolicy,
                  trailing: _settingsActionValue(context, t.general.open),
                  onTap: () async {
                    await launchUrl(
                      Uri.parse('https://localsend.org/privacy'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                if (checkPlatform([TargetPlatform.iOS, TargetPlatform.macOS]))
                  M3eSettingsRow(
                    icon: Icons.gavel_outlined,
                    title: t.settingsTab.other.termsOfUse,
                    supportingText: t.settingsTab.other.termsOfUseDescription,
                    semanticLabel: t.settingsTab.other.termsOfUse,
                    trailing: _settingsActionValue(context, t.general.open),
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(
                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
              ],
            ),
            M3eSettingsRow(
              icon: Icons.tune,
              title: t.settingsTab.advancedSettings,
              supportingText: t.settingsTab.advancedSettingsDescription,
              semanticLabel: t.settingsTab.advancedSettings,
              trailing: M3eExpressiveSwitch(
                value: vm.advanced,
                onChanged: (b) async {
                  vm.onTapAdvanced(b);
                  await ref.notifier(settingsProvider).setAdvancedSettingsEnabled(b);
                },
                semanticLabel: '${t.settingsTab.advancedSettings}, ${vm.advanced ? t.general.on : t.general.off}',
              ),
            ),
            const SizedBox(height: 20),
            const LocalSendLogo(withText: true),
            const SizedBox(height: 5),
            ref
                .watch(versionProvider)
                .maybeWhen(
                  data: (version) => Text(
                    'Version: ${version.combinedString}',
                    textAlign: TextAlign.center,
                  ),
                  orElse: () => Container(),
                ),
            Text(
              '© ${DateTime.now().year} Tien Do Nam',
              textAlign: TextAlign.center,
            ),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () async {
                  await context.push(() => const ChangelogPage());
                },
                icon: const Icon(Icons.history),
                label: Text(t.changelogPage.title),
              ),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

Widget _settingsActionValue(BuildContext context, String value) {
  final scheme = Theme.of(context).colorScheme;
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 240),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
        ),
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Icon(
            Icons.chevron_right,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? supportingText;
  final List<Widget> children;
  final EdgeInsets padding;

  const _SettingsSection({
    required this.title,
    required this.children,
    this.supportingText,
    this.padding = const EdgeInsets.only(bottom: 18),
  });

  @override
  Widget build(BuildContext context) {
    final horizontalInset = MediaQuery.sizeOf(context).width < 380 ? 12.0 : 16.0;
    return Padding(
      padding: padding,
      child: M3eSectionCard(
        title: title,
        supportingText: supportingText,
        padding: EdgeInsets.fromLTRB(horizontalInset, 22, horizontalInset, 10),
        children: children,
      ),
    );
  }
}

extension on ThemeMode {
  String get humanName {
    switch (this) {
      case ThemeMode.system:
        return t.settingsTab.general.brightnessOptions.system;
      case ThemeMode.light:
        return t.settingsTab.general.brightnessOptions.light;
      case ThemeMode.dark:
        return t.settingsTab.general.brightnessOptions.dark;
    }
  }
}

extension on ColorMode {
  String get humanName {
    return switch (this) {
      ColorMode.system => t.settingsTab.general.colorOptions.system,
      ColorMode.localsend => t.appName,
      ColorMode.oled => t.settingsTab.general.colorOptions.oled,
      ColorMode.yaru => 'Yaru',
      ColorMode.custom => t.settingsTab.general.colorOptions.custom,
    };
  }
}
