import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/provider/local_ip_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/ui/snackbar.dart';
import 'package:localsend_app/widget/dialogs/pin_dialog.dart';
import 'package:localsend_app/widget/dialogs/qr_dialog.dart';
import 'package:localsend_app/widget/dialogs/zoom_dialog.dart';
import 'package:localsend_app/widget/m3e/m3e_components.dart';
import 'package:localsend_app/widget/responsive_list_view.dart';
import 'package:localsend_isolates/util/sleep.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final _logger = Logger('WebSharePage');

enum _ServerState { initializing, running, error, stopping }

/// Shares a link with web browsers, in one of two modes:
/// - send: offers [WebSharePage.files] for download.
/// - receive: serves the upload page so browsers can upload files to this device.
///   Incoming requests are not listed here because they open the receive page
///   like any other incoming request.
class WebSharePage extends StatefulWidget {
  /// The files offered for download (share via link).
  /// `null` serves the upload page instead (receive via link).
  final List<CrossFile>? files;

  const WebSharePage({this.files});

  @override
  State<WebSharePage> createState() => _WebSharePageState();
}

class _WebSharePageState extends State<WebSharePage> with Refena {
  _ServerState _stateEnum = _ServerState.initializing;
  bool _encrypted = false;
  String? _initializedError;

  bool get _sendMode => widget.files != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init(encrypted: false);
    });
  }

  void _init({required bool encrypted}) async {
    final settings = ref.read(settingsProvider);
    setState(() {
      _stateEnum = _ServerState.initializing;
      _encrypted = encrypted;
      _initializedError = null;
    });
    await sleepAsync(500);
    try {
      final files = widget.files;

      // The pin of a previous web share session is kept;
      // receive mode initially uses the receive pin from settings.
      final previousState = ref.read(serverProvider);
      final wasWebActive = previousState?.webSendState != null || previousState?.webUpload == true;
      final webPin = wasWebActive ? previousState?.webPin : (files == null ? settings.receivePin : null);

      if (files != null) {
        // The auto accept setting of a previous web send state is kept.
        await ref
            .notifier(serverProvider)
            .restartServerWithWebSend(
              alias: settings.alias,
              port: settings.port,
              https: _encrypted,
              files: files,
              webPin: webPin,
            );
      } else {
        await ref
            .notifier(serverProvider)
            .restartServer(
              alias: settings.alias,
              port: settings.port,
              https: _encrypted,
              webUpload: true,
              webPin: webPin,
            );
      }
      setState(() {
        _stateEnum = _ServerState.running;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _stateEnum = _ServerState.error;
          _initializedError = e.toString();
        });
      }
    }
  }

  /// Web share uses unencrypted http by default, so we need to revert to the previous state.
  Future<void> _revertServerState() async {
    await ref.notifier(serverProvider).restartServerFromSettings();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) async {
        if (_stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping) {
          return;
        }

        setState(() {
          _stateEnum = _ServerState.stopping;
        });
        await sleepAsync(250);
        try {
          // Also needed in the error state: the failed restart already stopped the old server.
          await _revertServerState();
        } catch (e) {
          _logger.warning('Failed to restore the server', e);
        }
        await sleepAsync(250);

        if (context.mounted) {
          context.pop();
        }
      },
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_sendMode ? t.webSharePage.title : t.webReceivePage.title),
        ),
        body: Builder(
          builder: (context) {
            if (_stateEnum != _ServerState.running) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_stateEnum == _ServerState.initializing || _stateEnum == _ServerState.stopping) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        _stateEnum == _ServerState.initializing ? t.webSharePage.loading : t.webSharePage.stopping,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ] else if (_initializedError != null) ...[
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(t.webSharePage.error, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: SelectableText(_initializedError!, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ],
              );
            }

            final serverState = context.watch(serverProvider);
            final webSendState = serverState?.webSendState;
            if (serverState == null || (_sendMode && webSendState == null)) {
              // the server is restarting (e.g. because the pin changed)
              return const Center(child: CircularProgressIndicator());
            }
            final networkState = context.watch(localIpProvider);
            final settings = context.watch(settingsProvider);
            final pin = serverState.webPin;

            return ResponsiveListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              children: [
                Text(t.webSharePage.openLink(n: networkState.localIps.length), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.84),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(M3eTokens.cardRadius),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...networkState.localIps.map((ip) {
                          final url = '${_encrypted ? 'https' : 'http'}://$ip:${serverState.port}';
                          final urlWithPin = switch (pin) {
                            String() => '$url/?pin=${Uri.encodeQueryComponent(pin)}',
                            null => url,
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    url,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                M3eIconButton(
                                  icon: Icons.content_copy,
                                  tooltip: t.general.copy,
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: url));
                                    if (context.mounted && checkPlatformIsDesktop()) {
                                      context.showSnackBar(t.general.copiedToClipboard);
                                    }
                                  },
                                ),
                                M3eIconButton(
                                  icon: Icons.qr_code,
                                  tooltip: t.dialogs.qr.title,
                                  onPressed: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (_) => QrDialog(
                                        data: urlWithPin,
                                        label: url,
                                        listenIncomingWebSendRequests: _sendMode,
                                        pin: pin,
                                      ),
                                    );
                                  },
                                ),
                                M3eIconButton(
                                  icon: Icons.tv,
                                  tooltip: t.general.open,
                                  onPressed: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (_) => ZoomDialog(
                                        label: url,
                                        listenIncomingWebSendRequests: _sendMode,
                                        pin: pin,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (webSendState != null) ...[
                  Text(t.webSharePage.requests, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (webSendState.sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Text(t.webSharePage.noRequests),
                    ),
                  ...webSendState.sessions.entries.map((entry) {
                    final session = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.deviceInfo,
                                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        color: session.pending ? Theme.of(context).colorScheme.warning : null,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(session.ip, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (session.pending) ...[
                                TextButton(
                                  onPressed: () {
                                    ref.notifier(serverProvider).declineWebSendRequest(session.sessionId);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    iconSize: 24,
                                  ),
                                  child: const Icon(Icons.close),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.notifier(serverProvider).acceptWebSendRequest(session.sessionId);
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    iconSize: 24,
                                  ),
                                  child: const Icon(Icons.check_circle),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    t.general.accepted,
                                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                _WebShareBooleanRow(
                  label: t.webSharePage.encryption,
                  value: _encrypted,
                  onChanged: (value) {
                    _init(encrypted: value);
                  },
                ),
                if (_encrypted)
                  Text(
                    t.webSharePage.encryptionHint,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.warning),
                  ),
                _WebShareBooleanRow(
                  label: t.webSharePage.autoAccept,
                  value: webSendState != null ? webSendState.autoAccept : settings.receiveViaLinkAutoAccept,
                  onChanged: (value) async {
                    if (webSendState != null) {
                      ref.notifier(serverProvider).setWebSendAutoAccept(value);
                    } else {
                      await ref.notifier(settingsProvider).setReceiveViaLinkAutoAccept(value);
                    }
                  },
                ),
                _WebShareBooleanRow(
                  label: t.webSharePage.requirePin,
                  value: pin != null,
                  onChanged: (value) async {
                    if (pin != null) {
                      await ref.notifier(serverProvider).setWebPin(null);
                    } else {
                      final String? newPin = await showDialog<String>(
                        context: context,
                        builder: (_) => const PinDialog(
                          obscureText: false,
                          generateRandom: true,
                        ),
                      );

                      if (newPin != null && newPin.isNotEmpty) {
                        await ref.notifier(serverProvider).setWebPin(newPin);
                      }
                    }
                  },
                ),
                if (pin != null)
                  Text(
                    t.webSharePage.pinHint(pin: pin),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.warning),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WebShareBooleanRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _WebShareBooleanRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(M3eTokens.controlRadius),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              M3eExpressiveSwitch(
                value: value,
                onChanged: onChanged,
                semanticLabel: '$label, ${value ? t.general.on : t.general.off}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
