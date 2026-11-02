import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where private keys, passwords, passphrases and tokens live. Nothing secret goes into the database:
/// a row stores only the id it was saved under here.
///
/// Ids are namespaced, e.g. `key:<uuid>`, `password:<connection id>`, `token:github`.
abstract interface class SecretStore {
  Future<String?> read(String id);

  Future<void> write(String id, String value);

  Future<void> delete(String id);

  /// Ids starting with [prefix] (for cleanup and "used by" checks).
  Future<Set<String>> ids({String prefix = ''});
}

/// Android Keystore-backed storage (Keychain / libsecret / DPAPI on other platforms).
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String id) => _storage.read(key: id);

  @override
  Future<void> write(String id, String value) => _storage.write(key: id, value: value);

  @override
  Future<void> delete(String id) => _storage.delete(key: id);

  @override
  Future<Set<String>> ids({String prefix = ''}) async =>
      (await _storage.readAll()).keys.where((k) => k.startsWith(prefix)).toSet();
}

/// In-memory store for tests and previews.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String id) async => values[id];

  @override
  Future<void> write(String id, String value) async => values[id] = value;

  @override
  Future<void> delete(String id) async => values.remove(id);

  @override
  Future<Set<String>> ids({String prefix = ''}) async => values.keys.where((k) => k.startsWith(prefix)).toSet();
}

final secretStoreProvider = Provider<SecretStore>((ref) => PlatformSecretStore());
