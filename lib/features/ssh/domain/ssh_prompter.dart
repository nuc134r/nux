import '../../connections/domain/host_key_check.dart';

/// A server key that needs the user's decision.
class HostKeyQuestion {
  const HostKeyQuestion({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    required this.status,
    this.knownFingerprints = const [],
  });

  final String host;
  final int port;
  final String keyType;

  /// `SHA256:…`
  final String fingerprint;

  /// [HostKeyStatus.unknown], [HostKeyStatus.newKeyType] or [HostKeyStatus.changed].
  final HostKeyStatus status;

  /// What was trusted before (`type SHA256:…`), for the changed/new-type warnings.
  final List<String> knownFingerprints;
}

class SecretAnswer {
  const SecretAnswer(this.value, {this.remember = false});

  final String value;

  /// Password: save it in secure storage. Passphrase: keep the key unlocked until the app closes.
  final bool remember;
}

class KeyboardInteractivePrompt {
  const KeyboardInteractivePrompt(this.text, {required this.echo});

  final String text;
  final bool echo;
}

/// Questions the SSH layer asks while connecting. The app answers them with dialogs; tests with fakes.
/// Returning null means the user cancelled.
abstract interface class SshPrompter {
  Future<bool> confirmHostKey(HostKeyQuestion question);

  Future<SecretAnswer?> password({required String connectionName, required String address, required bool retry});

  Future<SecretAnswer?> passphrase({required String identityName, required bool retry});

  Future<List<String>?> keyboardInteractive({
    required String address,
    required String name,
    required String instruction,
    required List<KeyboardInteractivePrompt> prompts,
  });

  /// Device unlock (fingerprint, face, PIN) before using a key that requires it.
  Future<bool> authenticateUser({required String reason});
}
