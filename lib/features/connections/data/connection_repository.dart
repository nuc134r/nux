import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/secure/secret_store.dart';

extension ConnectionIdentities on Connection {
  List<String> get identityIdList => (jsonDecode(identityIds) as List).cast<String>();

  /// `user@host` (with `:port` when not 22).
  String get address => '$username@$host${port == 22 ? '' : ':$port'}';
}

String encodeIdentityIds(List<String> ids) => jsonEncode(ids);

class ConnectionRepository {
  ConnectionRepository(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  static String passwordSecretId(String connectionId) => 'password:$connectionId';

  Stream<List<Connection>> watchAll() => (_db.select(_db.connections)
        ..orderBy([
          (c) => OrderingTerm(expression: c.groupName.isNull(), mode: OrderingMode.desc),
          (c) => OrderingTerm(expression: c.groupName),
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.name.lower()),
        ]))
      .watch();

  Future<List<Connection>> all() => _db.select(_db.connections).get();

  Future<Connection?> get(String id) => (_db.select(_db.connections)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<Connection?> watch(String id) =>
      (_db.select(_db.connections)..where((c) => c.id.equals(id))).watchSingleOrNull();

  /// Inserts or updates; returns the id.
  Future<String> save(ConnectionsCompanion data) async {
    final now = clock.now();
    if (data.id.present) {
      await (_db.update(_db.connections)..where((c) => c.id.equals(data.id.value)))
          .write(data.copyWith(updatedAt: Value(now)));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.connections).insert(data.copyWith(id: Value(id), createdAt: Value(now), updatedAt: Value(now)));
    return id;
  }

  Future<void> markUsed(String id) => (_db.update(_db.connections)..where((c) => c.id.equals(id)))
      .write(ConnectionsCompanion(lastUsedAt: Value(clock.now())));

  /// Connections that jump through [id].
  Future<List<Connection>> jumpingThrough(String id) =>
      (_db.select(_db.connections)..where((c) => c.jumpHostId.equals(id))).get();

  Future<void> delete(String id) async {
    await (_db.delete(_db.connections)..where((c) => c.id.equals(id))).go();
    await _secrets.delete(passwordSecretId(id));
  }

  Future<String?> savedPassword(String id) => _secrets.read(passwordSecretId(id));

  Future<void> setSavedPassword(String id, String? password) async {
    if (password == null || password.isEmpty) {
      await _secrets.delete(passwordSecretId(id));
      await (_db.update(_db.connections)..where((c) => c.id.equals(id)))
          .write(ConnectionsCompanion(savePassword: const Value(false), updatedAt: Value(clock.now())));
    } else {
      await _secrets.write(passwordSecretId(id), password);
      await (_db.update(_db.connections)..where((c) => c.id.equals(id)))
          .write(ConnectionsCompanion(savePassword: const Value(true), updatedAt: Value(clock.now())));
    }
  }

  /// Puts [identityId] first in the connection's key list (e.g. after installing it on the server).
  Future<void> preferIdentity(String connectionId, String identityId) async {
    final c = await get(connectionId);
    if (c == null) return;
    final ids = [identityId, ...c.identityIdList.where((i) => i != identityId)];
    await save(ConnectionsCompanion(id: Value(connectionId), identityIds: Value(encodeIdentityIds(ids))));
  }
}

final connectionRepositoryProvider =
    Provider((ref) => ConnectionRepository(ref.watch(appDatabaseProvider), ref.watch(secretStoreProvider)));

final connectionsProvider = StreamProvider<List<Connection>>((ref) => ref.watch(connectionRepositoryProvider).watchAll());

final connectionProvider =
    StreamProvider.family<Connection?, String>((ref, id) => ref.watch(connectionRepositoryProvider).watch(id));
