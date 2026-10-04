import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Terminal receive results retained until their progress route is dismissed.
/// The HTTP server can accept the next transfer without erasing a confirmation
/// or making an older progress route act on the new session.
final receiveResultsProvider = NotifierProvider<ReceiveResultsNotifier, Map<String, ReceiveSessionState>>((ref) => ReceiveResultsNotifier());

class ReceiveResultsNotifier extends Notifier<Map<String, ReceiveSessionState>> {
  @override
  Map<String, ReceiveSessionState> init() => {};

  void retain(ReceiveSessionState session) {
    state = {...state, session.sessionId: session};
  }

  void remove(String sessionId) {
    if (!state.containsKey(sessionId)) return;
    state = {...state}..remove(sessionId);
  }
}
