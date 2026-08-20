import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/config/init.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/tabs/receive_tab.dart';
import 'package:localsend_app/pages/tabs/send_tab.dart';
import 'package:localsend_app/pages/tabs/settings_tab.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/native/cross_file_converters.dart';
import 'package:localsend_app/widget/m3e/m3e_background.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.download_for_offline_outlined),
  send(Icons.send),
  settings(Icons.settings)
  ;

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        if (event.files.length == 1 && Directory(event.files.first.path).existsSync()) {
          // user dropped a directory
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(event.files.first.path));
        } else {
          // user dropped one or more files
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: event.files,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          return M3eExpressiveBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                children: [
                  if (!sizingInformation.isMobile)
                    NavigationRail(
                      selectedIndex: vm.currentTab.index,
                      onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                      extended: sizingInformation.isDesktop,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
                      leading: sizingInformation.isDesktop
                          ? const Column(
                              children: [
                                SizedBox(height: 20),
                                Text(
                                  'LocalSend',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 20),
                              ],
                            )
                          : null,
                      destinations: HomeTab.values.map((tab) {
                        return NavigationRailDestination(
                          icon: Icon(tab.icon),
                          label: Text(tab.label),
                        );
                      }).toList(),
                    ),
                  Expanded(
                    child: SafeArea(
                      left: sizingInformation.isMobile,
                      child: Stack(
                        children: [
                          PageView(
                            controller: vm.controller,
                            physics: const NeverScrollableScrollPhysics(),
                            children: const [
                              ReceiveTab(),
                              SendTab(),
                              SettingsTab(),
                            ],
                          ),
                          if (_dragAndDropIndicator)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.file_download, size: 128),
                                  const SizedBox(height: 30),
                                  Text(t.sendTab.placeItems, style: Theme.of(context).textTheme.titleLarge),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: sizingInformation.isMobile
                  ? M3eFloatingNavigationBar(
                      selectedIndex: vm.currentTab.index,
                      destinations: HomeTab.values
                          .map(
                            (tab) => M3eNavigationDestination(
                              icon: tab.icon,
                              label: tab.label,
                              onTap: () => vm.changeTab(tab),
                            ),
                          )
                          .toList(),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
