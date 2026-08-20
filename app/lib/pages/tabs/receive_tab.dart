import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:localsend_app/pages/home_page_controller.dart';
import 'package:localsend_app/pages/receive_history_page.dart';
import 'package:localsend_app/pages/web_share_page.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/widget/animations/initial_fade_transition.dart';
import 'package:localsend_app/widget/column_list_view.dart';
import 'package:localsend_app/widget/local_send_logo.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_app/widget/rotating_widget.dart';
import 'package:localsend_isolates/util/sleep.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab();

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  /// Whether the advanced network info is shown.
  bool _showAdvanced = false;

  /// Whether the history button is shown.
  /// This extra boolean is needed to delay the animation.
  bool _showHistoryButton = true;

  Future<void> _toggleAdvanced() async {
    if (_showAdvanced) {
      setState(() => _showAdvanced = false);
      await sleepAsync(200);
      if (mounted) {
        setState(() => _showHistoryButton = true);
      }
    } else {
      setState(() {
        _showAdvanced = true;
        _showHistoryButton = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alias = context.watch(settingsProvider.select((s) => s.alias));
    final serverState = context.watch(serverProvider);
    final localIps = context.watch(localIpProvider.select((s) => s.localIps));
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveListView.defaultMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 8),
              child: ColumnListView(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 540),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 34),
                            InitialFadeTransition(
                              duration: const Duration(milliseconds: 300),
                              delay: const Duration(milliseconds: 200),
                              child: Consumer(
                                builder: (context, ref) {
                                  final animations = ref.watch(animationProvider);
                                  final activeTab = ref.watch(homePageControllerProvider.select((state) => state.currentTab));
                                  return RotatingWidget(
                                    duration: const Duration(seconds: 15),
                                    spinning: serverState != null && animations && activeTab == HomeTab.receive,
                                    child: const LocalSendLogo(withText: false),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                serverState?.alias ?? alias,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.receiveTab.subtitle,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Visibility(
                              visible: serverState == null,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: InitialFadeTransition(
                                duration: const Duration(milliseconds: 300),
                                delay: const Duration(milliseconds: 500),
                                child: Text(
                                  t.general.offline,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 42),
                            M3eTonalActionButton(
                              icon: Icons.language,
                              label: t.receiveTab.link,
                              onPressed: () async {
                                await context.global.dispatchAsync(NavigateAction.push(const WebSharePage()));
                              },
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _InfoBox(
          serverState: serverState,
          localIps: localIps,
          showAdvanced: _showAdvanced,
        ),
        _CornerButtons(
          showAdvanced: _showAdvanced,
          showHistoryButton: _showHistoryButton,
          toggleAdvanced: _toggleAdvanced,
        ),
      ],
    );
  }
}

class _CornerButtons extends StatelessWidget {
  final bool showAdvanced;
  final bool showHistoryButton;
  final Future<void> Function() toggleAdvanced;

  const _CornerButtons({
    required this.showAdvanced,
    required this.showHistoryButton,
    required this.toggleAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!showAdvanced)
              AnimatedOpacity(
                opacity: showHistoryButton ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: M3eIconButton(
                  tooltip: t.receiveHistoryPage.title,
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  icon: Icons.history,
                ),
              ),
            const SizedBox(width: 10),
            M3eIconButton(
              key: const ValueKey('info-btn'),
              tooltip: t.receiveHistoryPage.entryActions.info,
              onPressed: toggleAdvanced,
              icon: Icons.info_outline,
              selected: showAdvanced,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final ServerState? serverState;
  final List<String> localIps;
  final bool showAdvanced;

  const _InfoBox({
    required this.serverState,
    required this.localIps,
    required this.showAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedCrossFade(
      crossFadeState: showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      firstChild: const SizedBox.shrink(),
      secondChild: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, top: 78, right: 18),
          child: Card(
            margin: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.alias),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: SelectableText(serverState?.alias ?? '-'),
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.ip),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (localIps.isEmpty) Text(t.general.unknown),
                          ...localIps.map((ip) => SelectableText(ip)),
                        ],
                      ),
                    ],
                  ),
                  TableRow(
                    children: [
                      Text(t.receiveTab.infoBox.port),
                      const SizedBox(width: 10),
                      SelectableText(serverState?.port.toString() ?? '-'),
                    ],
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
