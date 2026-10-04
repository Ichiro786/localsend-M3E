import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/persistence/color_mode.dart';
import 'package:localsend_app/model/send_mode.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/send/sending_file.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/model/state/server/receiving_file.dart';
import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/controller/receive_controller.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/network/server/server_utils.dart';
import 'package:localsend_app/provider/receive_history_provider.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_isolates/isolate.dart';
import 'package:localsend_isolates/model/device.dart';
import 'package:localsend_isolates/model/device_info_result.dart';
import 'package:localsend_isolates/model/dto/file_dto.dart';
import 'package:localsend_isolates/model/file_type.dart';
import 'package:localsend_isolates/model/session_status.dart';
import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';

import '../mocks.mocks.dart';

class TransferFixture {
  late final RefenaContainer container;
  late final ReceiveController receiver;
  final persistence = MockPersistenceService();
  late final FixtureServer server;
  late final FixtureSend sender;

  TransferFixture({ReceiveSessionState? receive, SendSessionState? send, SettingsState? settings}) {
    final initialSettings = settings ?? transferSettings();
    when(persistence.getReceiveHistory()).thenReturn([]);
    when(persistence.isSaveToHistory()).thenReturn(false);
    server = FixtureServer(receive);
    sender = FixtureSend(send);
    container = RefenaContainer(overrides: [
      settingsProvider.overrideWithNotifier((_) => FixtureSettings(initialSettings)),
      serverProvider.overrideWithNotifier((_) => server),
      sendProvider.overrideWithNotifier((_) => sender),
      receiveHistoryProvider.overrideWithNotifier((_) => ReceiveHistoryService(persistence)),
      parentIsolateProvider.overrideWithNotifier((_) => IsolateController(initialState: ParentIsolateState.initial(SyncState(
        rootIsolateToken: Object(),
        securityContext: const StoredSecurityContext(privateKey: '', publicKey: '', certificate: '', certificateHash: ''),
        deviceInfo: DeviceInfoResult(deviceType: DeviceType.mobile, deviceModel: null, androidSdkInt: 35),
        alias: 'Fixture', port: 53317, protocol: ProtocolType.http, multicastGroup: '224.0.0.167',
        networkWhitelist: null, networkBlacklist: null, discoveryTimeout: 5, serverRunning: true, download: false,
      )))),
    ]);
    container.read(serverProvider);
    container.read(sendProvider);
    receiver = ReceiveController(ServerUtils(refFunc: () => container, getState: () => container.read(serverProvider)!,
      getStateOrNull: () => container.read(serverProvider), setState: server.apply));
  }
}

class FixtureServer extends ServerService {
  final ReceiveSessionState? initial;
  final closed = <String>[];
  final cancelled = <String>[];
  FixtureServer(this.initial);
  @override
  ServerState init() => ServerState(alias: 'Fixture', port: 53317, https: false, webSendState: null, webUpload: false, webPin: null, session: initial);
  void apply(ServerState? Function(ServerState?) update) { state = update(state); }
  void setSession(ReceiveSessionState? session) { state = state!.copyWith(session: session); }
  @override
  void closeSession() {
    if (state?.session != null) closed.add(state!.session!.sessionId);
    super.closeSession();
  }
  @override
  void cancelSession() {
    if (state?.session != null) cancelled.add(state!.session!.sessionId);
    closeSession();
  }
}

class FixtureSend extends SendNotifier {
  final SendSessionState? initial;
  final closed = <String>[];
  FixtureSend(this.initial);
  @override
  Map<String, SendSessionState> init() => initial == null ? {} : {initial!.sessionId: initial!};
  void setSession(SendSessionState session) { state = {...state, session.sessionId: session}; }
  @override
  void closeSession(String id) { closed.add(id); super.closeSession(id); }
}

class FixtureSettings extends SettingsService {
  final SettingsState initial;
  FixtureSettings(this.initial) : super(MockPersistenceService());
  @override
  SettingsState init() => initial;
}

FileDto transferFile(String id, {int size = 10}) => FileDto(id: id, fileName: '$id.bin', size: size, fileType: FileType.other,
  hash: null, preview: null, metadata: null);

ReceiveSessionState receiveSession(String id, {SessionStatus status = SessionStatus.sending, int count = 1, int size = 10}) => ReceiveSessionState(
  sessionId: id, status: status, sender: Device.empty, senderAlias: 'Fixture',
  files: {for(var i=0; i<count; i++) 'file-$i': ReceivingFile(file: transferFile('file-$i', size: size), token: 'token',
    desiredName: '$id-file-$i.bin', path: null, savedToGallery: false, errorMessage: null)},
  startTime: null, endTime: null, destinationDirectory: '/downloads', cacheDirectory: '/cache', saveToGallery: false, createdDirectories: {},
);

SendSessionState sendSession(String id, {SessionStatus status = SessionStatus.sending}) => SendSessionState(
  sessionId: id, remoteSessionId: 'remote-$id', background: false, status: status, target: Device.empty,
  files: {'outgoing': SendingFile(file: transferFile('outgoing'), token: 'token', thumbnail: null, asset: null, path: null,
    bytes: null, errorMessage: null)}, hashedFileCount: 1, startTime: null, endTime: null, sendingTasks: [], errorMessage: null,
);

HttpServerFileUploadResultEvent receiveResult(String id, {String fileId = 'file-0', String? error, bool gallery = false}) =>
  HttpServerFileUploadResultEvent(sessionId: id, fileId: fileId, path: error != null || gallery ? null : '/downloads/$id-$fileId.bin',
    savedToGallery: gallery, error: error);

SettingsState transferSettings({bool autoFinish = true, bool quickSave = false, bool quickSaveFromFavorites = false}) {
  return SettingsState(
    showToken: '',
    alias: 'LocalSend test device',
    theme: ThemeMode.system,
    colorMode: ColorMode.oled,
    customColor: const Color(0xFF000000),
    locale: AppLocale.en,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: null,
    saveToGallery: false,
    saveToHistory: false,
    quickSave: quickSave,
    quickSaveFromFavorites: quickSaveFromFavorites,
    receivePin: null,
    autoFinish: autoFinish,
    minimizeToTray: false,
    https: false,
    sendMode: SendMode.multiple,
    saveWindowPlacement: false,
    deviceType: DeviceType.desktop,
    deviceModel: null,
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: false,
    verifyChecksums: false,
    discoveryTimeout: 5,
    advancedSettings: false,
  );
}

