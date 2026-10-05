import 'dart:async';

import 'package:collection/collection.dart';
import 'package:localsend_isolates/constants.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/rust/api/discovery.dart';
import 'package:localsend_isolates/rust/api/model.dart' as rust_model;
import 'package:localsend_isolates/src/isolate/child/sync_provider.dart';
import 'package:localsend_isolates/util/rust.dart';
import 'package:logging/logging.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('Discovery');

final discoveryProvider = Provider((ref) {
  return DiscoveryService(ref);
});

/// Owns the Rust discovery (`core/discovery`): the multicast sockets, the
/// register requests answering announcements, the subnet scans and the store
/// of confirmed devices all live on the Rust side. This service configures it
/// from the [syncProvider] state and maps every confirmation to a [Device].
class DiscoveryService {
  DiscoveryService(this._ref, {Future<RsDiscovery> Function(SyncState)? start}) : _start = start ?? _startFromState;

  final Future<RsDiscovery> Function(SyncState) _start;
  int _configurationVersion = 0;

  final Ref _ref;
  RsDiscovery? _discovery;
  Completer<void> _retryCompleter = Completer();
  bool _listening = false;
  StreamSubscription<dynamic>? _syncSubscription;

  /// Whether the current discovery was stopped by [restartListener], as
  /// opposed to stopping itself because the multicast sockets failed.
  bool _restartRequested = false;

  /// Starts the discovery and emits every device confirmation:
  /// answered announcements, scan results and devices fed in
  /// via [addDevice] all arrive on this one stream.
  Stream<Device> startListener() {
    if (_listening) {
      _logger.info('Already listening to discovery');
      return const Stream.empty();
    }

    _listening = true;

    final devices = StreamController<Device>(
      onCancel: () async {
        _listening = false;
        _configurationVersion++;
        await _syncSubscription?.cancel();
        if (!_retryCompleter.isCompleted) _retryCompleter.complete();
        await _discovery?.stop();
      },
    );
    unawaited(_runListener(devices));
    return devices.stream;
  }

  Future<void> _runListener(StreamController<Device> devices) async {
    // Announcements are only answered while the server runs: the answer would
    // advertise an HTTP port that nobody listens on otherwise.
    _syncSubscription = _ref.stream(syncProvider).listen((event) {
      if (_configurationChanged(event.prev, event.next)) {
        restartListener();
      } else if (event.prev.serverRunning != event.next.serverRunning) {
        unawaited(_discovery?.setAnswerAnnouncements(answer: event.next.serverRunning));
      }
    });

    while (_listening) {
      final syncState = _ref.read(syncProvider);
      final configurationVersion = _configurationVersion;

      final RsDiscovery discovery;
      try {
        discovery = await _start(syncState);
      } catch (e) {
        _logger.warning('Could not start discovery (group: ${syncState.multicastGroup}, port: ${syncState.port})', e);
        if (!_listening || configurationVersion != _configurationVersion) continue;
        // Wait for the next restart request instead of hot-looping
        _retryCompleter = Completer();
        await _retryCompleter.future;
        continue;
      }

      final multicastError = await discovery.multicastError();
      if (multicastError != null) {
        _logger.warning('Discovery runs without multicast (group: ${syncState.multicastGroup}, port: ${syncState.port}): $multicastError');
      }

      if (!_ref.read(syncProvider).serverRunning) {
        await discovery.setAnswerAnnouncements(answer: false);
      }

      // Settings or a restart may arrive while the native handle is starting.
      // Never publish or announce a handle created from an obsolete snapshot.
      if (!_listening || configurationVersion != _configurationVersion) {
        await discovery.stop();
        continue;
      }
      _discovery = discovery;

      // Tell everyone in the network that I am online.
      unawaited(discovery.announce());

      await for (final device in discovery.listen()) {
        if (!devices.isClosed) {
          devices.add(device.toDevice());
        }
      }

      _discovery = null;
      if (!_listening) break;

      if (_restartRequested) {
        // The stream ended because [restartListener] stopped the discovery.
        _restartRequested = false;
      } else {
        // The stream ended because the multicast sockets failed permanently,
        // e.g. because iOS reclaimed them while the app was suspended.
        // The delay avoids hot-looping when binding keeps succeeding but the
        // sockets keep failing right away.
        _logger.warning('Discovery stopped unexpectedly (multicast sockets failed). Restarting discovery.');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Restarts the discovery, e.g. after the port or the network settings changed.
  void restartListener() {
    _configurationVersion++;
    final discovery = _discovery;
    if (discovery != null) {
      // Ends the listen stream, which makes [startListener] rebind.
      _restartRequested = true;
      unawaited(discovery.stop());
    } else if (!_retryCompleter.isCompleted) {
      // Starting failed previously; let [startListener] try again.
      _retryCompleter.complete();
    }
  }

  /// Sends an announcement which triggers a response on every LocalSend member of the network.
  Future<void> sendAnnouncement() async {
    final discovery = _discovery;
    if (discovery == null) {
      _logger.info('Discovery is not running, skipping announcement');
      return;
    }

    _logger.info('Announce via UDP');
    await discovery.announce();
  }

  /// Scans the subnet of [networkInterface] by probing every host over HTTP,
  /// for networks that do not carry multicast.
  /// Found devices arrive on the [startListener] stream; this method returns
  /// once the whole scan has finished.
  Future<void> scanSubnet({required String networkInterface, required int port, required bool https}) async {
    final discovery = _discovery;
    if (discovery == null) {
      _logger.info('Discovery is not running, skipping subnet scan');
      return;
    }

    await discovery.scanSubnet(
      interfaceIp: networkInterface,
      port: port,
      protocol: https ? rust_model.ProtocolType.https : rust_model.ProtocolType.http,
    );
  }

  /// Discovers devices in stages, cheapest first: announces this device and
  /// probes the known addresses of the favorites, then falls back to scanning
  /// the subnets of [networkInterfaces] when nothing was confirmed within the
  /// grace period.
  /// Found devices arrive on the [startListener] stream; this method returns
  /// once every stage has finished, including the whole announcement burst.
  Future<void> discoverStaged({
    required List<(String, int)> favorites,
    required List<String> networkInterfaces,
    required int port,
    required bool https,
    required Duration grace,
  }) async {
    final discovery = _discovery;
    if (discovery == null) {
      _logger.info('Discovery is not running, skipping staged discovery');
      return;
    }

    final protocol = https ? rust_model.ProtocolType.https : rust_model.ProtocolType.http;
    await discovery.discoverStaged(
      channels: [
        for (final (host, port) in favorites) RsDeviceChannel(host: host, port: port, protocol: protocol),
      ],
      interfaceIps: networkInterfaces,
      port: port,
      protocol: protocol,
      graceMs: BigInt.from(grace.inMilliseconds),
    );
  }

  /// The retained confirmations of a stored device, oldest first.
  /// Empty when the fingerprint is unknown or the discovery is not running.
  Future<List<DeviceLog>> deviceLogs(String fingerprint) async {
    final discovery = _discovery;
    if (discovery == null) {
      _logger.info('Discovery is not running, skipping device logs');
      return const [];
    }

    final logs = await discovery.deviceLogs(fingerprint: fingerprint);
    return logs.map((log) => log.toDeviceLog()).toList();
  }

  /// Feeds a device confirmed outside of the discovery into the store, e.g.
  /// one that registered with this device's HTTP server.
  /// The device comes back on the [startListener] stream.
  Future<void> addDevice(Device device) async {
    final discovery = _discovery;
    final ip = device.ip;
    if (discovery == null || ip == null) {
      // A device lost here re-appears on its next register request, which the
      // announcement sent when the discovery (re)starts triggers by itself.
      _logger.info('Discovery is not running, skipping device ${device.alias} ($ip)');
      return;
    }

    await discovery.addDevice(device: device.toRsDiscoveredDevice(ip));
  }
}

bool _configurationChanged(SyncState prev, SyncState next) {
  const lists = ListEquality<String>();
  return prev.alias != next.alias ||
      prev.port != next.port ||
      prev.protocol != next.protocol ||
      prev.multicastGroup != next.multicastGroup ||
      prev.discoveryTimeout != next.discoveryTimeout ||
      prev.download != next.download ||
      prev.securityContext != next.securityContext ||
      prev.deviceInfo.deviceModel != next.deviceInfo.deviceModel ||
      prev.deviceInfo.deviceType != next.deviceInfo.deviceType ||
      !lists.equals(prev.networkWhitelist, next.networkWhitelist) ||
      !lists.equals(prev.networkBlacklist, next.networkBlacklist);
}

Future<RsDiscovery> _startFromState(SyncState syncState) {
  return startDiscovery(
    group: syncState.multicastGroup,
    port: syncState.port,
    networkWhitelist: syncState.networkWhitelist,
    networkBlacklist: syncState.networkBlacklist,
    alias: syncState.alias,
    version: protocolVersion,
    deviceModel: syncState.deviceInfo.deviceModel,
    deviceType: syncState.deviceInfo.deviceType.toRust(),
    fingerprint: syncState.securityContext.certificateHash,
    protocol: syncState.protocol.toRust(),
    download: syncState.download,
    certPem: syncState.securityContext.certificate,
    privateKeyPem: syncState.securityContext.privateKey,
    timeoutMs: BigInt.from(syncState.discoveryTimeout),
  );
}
