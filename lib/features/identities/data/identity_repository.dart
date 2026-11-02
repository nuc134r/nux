import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/secure/secret_store.dart';
import '../../connections/data/connection_repository.dart';
import '../domain/key_import.dart';
import '../domain/key_material.dart';

/// SSH keys: public data in the database, the private key in [SecretStore].
class IdentityRepository {
  IdentityRepository(this._db, this._secrets, this._connections);

  final AppDatabase _db;
  final SecretStore _secrets;
  final ConnectionRepository _connections;

  static String keySecretId(String identityId) => 'key:$identityId';

  Stream<List<Identity>> watchAll() =>
      (_db.select(_db.identities)..orderBy([(i) => OrderingTerm(expression: i.name.lower())])).watch();

  Future<List<Identity>> all() => _db.select(_db.identities).get();

  Future<Identity?> get(String id) => (_db.select(_db.identities)..where((i) => i.id.equals(id))).getSingleOrNull();

  Stream<Identity?> watch(String id) => (_db.select(_db.identities)..where((i) => i.id.equals(id))).watchSingleOrNull();

  /// Saves a new key. With a [passphrase], the stored private key is encrypted with it and has to be
  /// unlocked on use.
  Future<String> add(KeyMaterial key, {required String name, String? passphrase, bool requireBiometric = false}) async {
    final id = newId();
    final now = clock.now();
    final encrypted = passphrase != null && passphrase.isNotEmpty;
    await _secrets.write(keySecretId(id), key.toOpenSsh(passphrase: encrypted ? passphrase : null));
    await _db.into(_db.identities).insert(IdentitiesCompanion.insert(
          id: Value(id),
          createdAt: now,
          updatedAt: now,
          name: name,
          algorithm: key.algorithm,
          bits: key.bits,
          publicKey: key.publicLine(),
          fingerprint: sha256Fingerprint(key.publicBlob),
          encrypted: Value(encrypted),
          requireBiometric: Value(requireBiometric),
        ));
    return id;
  }

  /// The private key, decrypted. Throws [KeyImportException] (e.g. a wrong [passphrase]).
  Future<KeyMaterial> unlock(String id, {String? passphrase}) async {
    final text = await _secrets.read(keySecretId(id));
    if (text == null) throw StateError('The private key of this identity is missing from secure storage');
    return importPrivateKey(text, passphrase: passphrase);
  }

  /// Re-encrypts the stored key with [newPassphrase] (null or empty removes the passphrase).
  Future<void> changePassphrase(String id, {String? oldPassphrase, String? newPassphrase}) async {
    final key = await unlock(id, passphrase: oldPassphrase);
    final encrypted = newPassphrase != null && newPassphrase.isNotEmpty;
    await _secrets.write(keySecretId(id), key.toOpenSsh(passphrase: encrypted ? newPassphrase : null));
    await (_db.update(_db.identities)..where((i) => i.id.equals(id)))
        .write(IdentitiesCompanion(encrypted: Value(encrypted), updatedAt: Value(clock.now())));
  }

  Future<void> update(String id, {String? name, bool? requireBiometric}) =>
      (_db.update(_db.identities)..where((i) => i.id.equals(id))).write(IdentitiesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        requireBiometric: requireBiometric == null ? const Value.absent() : Value(requireBiometric),
        updatedAt: Value(clock.now()),
      ));

  /// Connections that offer this key.
  Future<List<Connection>> usedBy(String id) async =>
      (await _connections.all()).where((c) => c.identityIdList.contains(id)).toList();

  /// Deletes the key and removes it from every connection.
  Future<void> delete(String id) async {
    for (final c in await usedBy(id)) {
      await _connections.save(ConnectionsCompanion(
        id: Value(c.id),
        identityIds: Value(encodeIdentityIds(c.identityIdList.where((i) => i != id).toList())),
      ));
    }
    await (_db.delete(_db.identities)..where((i) => i.id.equals(id))).go();
    await _secrets.delete(keySecretId(id));
  }
}

final identityRepositoryProvider = Provider((ref) => IdentityRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(secretStoreProvider),
      ref.watch(connectionRepositoryProvider),
    ));

final identitiesProvider = StreamProvider<List<Identity>>((ref) => ref.watch(identityRepositoryProvider).watchAll());

final identityProvider =
    StreamProvider.family<Identity?, String>((ref, id) => ref.watch(identityRepositoryProvider).watch(id));
