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
    final motionAllowed = context.ref.read(animationProvider) && !MediaQuery.disableAnimationsOf(context);
    if (_showAdvanced) {
      setState(() => _showAdvanced = false);
      if (motionAllowed) {
        await sleepAsync(200);
      }
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
    final motionAllowed = context.watch(animationProvider) && !MediaQuery.disableAnimationsOf(context);
    final serverState = context.watch(serverProvider);
    final localIps = context.watch(localIpProvider.select((s) => s.localIps));
    final scheme = Theme.of(context).colorScheme;
    const horizontalInset = 22.0;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidthForCta = viewportWidth * 0.55 + horizontalInset * 2;
    final pageMaxWidth = contentMaxWidthForCta > ResponsiveListView.defaultMaxWidth ? contentMaxWidthForCta : ResponsiveListView.defaultMaxWidth;

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: pageMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                horizontalInset,
                30,
                horizontalInset,
                8,
              ),
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
                            const SizedBox(height: 24),
                            InitialFadeTransition(
                              duration: const Duration(milliseconds: 300),
                              delay: const Duration(milliseconds: 200),
                              child: Consumer(
                                builder: (context, ref) {
                                  final animations = ref.watch(
                                    animationProvider,
                                  );
                                  final motionAllowed = animations && !MediaQuery.of(context).disableAnimations;
                                  final activeTab = ref.watch(
                                    homePageControllerProvider.select(
                                      (state) => state.currentTab,
                                    ),
                                  );
                                  return RotatingWidget(
                                    duration: const Duration(seconds: 15),
                                    spinning: serverState != null && motionAllowed && activeTab == HomeTab.receive,
                                    child: const LocalSendLogo(withText: false),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'LocalSend',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.receiveTab.subtitle,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                serverState?.alias ?? alias,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ),
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
                            const SizedBox(height: 36),
                            Align(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: viewportWidth * 0.55,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: M3eTonalActionButton(
                                    icon: Icons.language,
                                    label: t.receiveTab.link,
                                    onPressed: () async {
                                      await context.global.dispatchAsync(
                                        NavigateAction.push(const WebSharePage()),
                                      );
                                    },
                                  ),
                                ),
                              ),
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
          motionAllowed: motionAllowed,
        ),
        _CornerButtons(
          showAdvanced: _showAdvanced,
          showHistoryButton: _showHistoryButton,
          motionAllowed: motionAllowed,
          toggleAdvanced: _toggleAdvanced,
        ),
      ],
    );
  }
}

class _CornerButtons extends StatelessWidget {
  final bool showAdvanced;
  final bool showHistoryButton;
  final bool motionAllowed;
  final Future<void> Function() toggleAdvanced;

  const _CornerButtons({
    required this.showAdvanced,
    required this.showHistoryButton,
    required this.motionAllowed,
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
                duration: motionAllowed ? const Duration(milliseconds: 200) : Duration.zero,
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
  final bool motionAllowed;

  const _InfoBox({
    required this.serverState,
    required this.localIps,
    required this.showAdvanced,
    required this.motionAllowed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3eMotionAwareCrossFade(
      motionAllowed: motionAllowed,
      crossFadeState: showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topLeft,
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
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
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
