import 'package:localsend_isolates/model/stored_security_context.dart';
import 'package:localsend_isolates/rust/api/crypto.dart' as rust;

/// Generates a random [StoredSecurityContext].
Future<StoredSecurityContext> generateSecurityContext() async {
  final result = await rust.generateSecurityContext();
  return StoredSecurityContext(
    privateKey: result.privateKey,
    publicKey: result.publicKey,
    certificate: result.certificate,
    certificateHash: result.certificateHash,
  );
}
