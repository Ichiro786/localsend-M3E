import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:localsend_isolates/model/dto/multicast_dto.dart';
import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:localsend_isolates/rust/api/discovery.dart';
import 'package:localsend_isolates/src/isolate/child/sync_provider.dart';
import 'package:localsend_isolates/src/task/discovery/discovery.dart';
import 'package:refena_flutter/refena_flutter.dart';

void main() {
  test('connection settings restart discovery while server status preserves the handle', () async {
    final initial = _fixture();
    final container = RefenaContainer(overrides: [syncProvider.overrideWithNotifier((_) => SyncService(initial: initial))]);
    addTearDown(container.disposeContainer);
    final starts = <SyncState>[];
    final handles = <_Discovery>[];
    final service = DiscoveryService(
      container,
      start: (state) async {
        starts.add(state);
        final handle = _Discovery();
        handles.add(handle);
        return handle;
      },
    );
    final subscription = service.startListener().listen((_) {});
    addTearDown(subscription.cancel);
    await _flush();
    expect(starts, hasLength(1));
    container.redux(syncProvider).dispatch(UpdateSyncStateAction(initial.copyWith(serverRunning: false)));
    await _flush();
    expect(starts, hasLength(1));
    expect(handles.single.answers.last, isFalse);
    var state = initial.copyWith(serverRunning: false);
    final changes = <SyncState Function(SyncState)>[
      (s) => s.copyWith(port: 54321),
      (s) => s.copyWith(protocol: ProtocolType.http),
      (s) => s.copyWith(alias: 'New name'),
      (s) => s.copyWith(multicastGroup: '224.0.0.168'),
      (s) => s.copyWith(networkWhitelist: ['192.168.1.0/24']),
      (s) => s.copyWith(networkBlacklist: ['10.0.0.0/8']),
      (s) => s.copyWith(discoveryTimeout: 3000),
      (s) => s.copyWith(download: true),
      (s) => s.copyWith(securityContext: initial.securityContext.copyWith(certificateHash: 'new-cert')),
      (s) => s.copyWith(
        deviceInfo: DeviceInfoResult(deviceType: DeviceType.mobile, deviceModel: 'New model', androidSdkInt: null),
      ),
    ];
    for (final change in changes) {
      final oldHandle = handles.last;
      state = change(state);
      container.redux(syncProvider).dispatch(UpdateSyncStateAction(state));
      await _flush();
      expect(oldHandle.stopped, isTrue);
      expect(starts.last, same(state));
      expect(handles.last.announcements, 1);
    }
    expect(starts, hasLength(changes.length + 1));
    container.redux(syncProvider).dispatch(UpdateSyncStateAction(state.copyWith(networkWhitelist: [...state.networkWhitelist!])));
    await _flush();
    expect(starts, hasLength(changes.length + 1), reason: 'equivalent filters must not rebind sockets');
  });

  test('settings changed during native startup discard stale handle before announcing', () async {
    final initial = _fixture();
    final container = RefenaContainer(overrides: [syncProvider.overrideWithNotifier((_) => SyncService(initial: initial))]);
    addTearDown(container.disposeContainer);
    final pending = Completer<RsDiscovery>();
    final stale = _Discovery();
    final current = _Discovery();
    final starts = <SyncState>[];
    final service = DiscoveryService(
      container,
      start: (state) {
        starts.add(state);
        return starts.length == 1 ? pending.future : Future.value(current);
      },
    );
    final subscription = service.startListener().listen((_) {});
    addTearDown(subscription.cancel);
    final updated = initial.copyWith(port: 54321, protocol: ProtocolType.http);
    container.redux(syncProvider).dispatch(UpdateSyncStateAction(updated));
    await _flush();
    pending.complete(stale);
    await _flush();
    expect(stale.stopped, isTrue);
    expect(stale.announcements, 0);
    expect(starts, hasLength(2));
    expect(starts.last, same(updated));
    expect(current.announcements, 1);
  });
}

Future<void> _flush() async {
  // Drain asynchronous stream and native-future continuations without wall-clock delays.
  for (var i = 0; i < 30; i++) {
    await Future<void>.value();
  }
}

class _Discovery implements RsDiscovery {
  final events = StreamController<RsStoredDevice>();
  final answers = <bool>[];
  int announcements = 0;
  bool stopped = false;
  @override
  Future<String?> multicastError() async => null;
  @override
  Future<void> setAnswerAnnouncements({required bool answer}) async {
    answers.add(answer);
  }

  @override
  Future<void> announce() async {
    announcements++;
  }

  @override
  Stream<RsStoredDevice> listen() => events.stream;
  @override
  Future<void> stop() async {
    stopped = true;
    final listening = events.hasListener;
    final closed = events.close();
    if (listening) await closed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SyncState _fixture() => SyncState(
  rootIsolateToken: Object(),
  securityContext: const StoredSecurityContext(privateKey: '', publicKey: '', certificate: '', certificateHash: 'cert'),
  deviceInfo: DeviceInfoResult(deviceType: DeviceType.desktop, deviceModel: 'Model', androidSdkInt: null),
  alias: 'Device',
  port: 53317,
  networkWhitelist: null,
  networkBlacklist: null,
  protocol: ProtocolType.https,
  multicastGroup: '224.0.0.167',
  discoveryTimeout: 1000,
  serverRunning: true,
  download: false,
);
