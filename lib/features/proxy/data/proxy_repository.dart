import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/secure/secret_store.dart';
import '../domain/socks5.dart';

extension ProxyAddress on Proxy {
  /// `host:port`, with `user@` when it logs in.
  String get address => '${username.isEmpty ? '' : '$username@'}$host:$port';
}

/// Saved SOCKS5 proxies; passwords in [SecretStore] as `proxy:<id>`.
class ProxyRepository {
  ProxyRepository(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  static String passwordSecretId(String proxyId) => 'proxy:$proxyId';

  Stream<List<Proxy>> watchAll() =>
      (_db.select(_db.proxies)..orderBy([(p) => OrderingTerm(expression: p.name.lower())])).watch();

  Future<List<Proxy>> all() => _db.select(_db.proxies).get();

  Future<Proxy?> get(String id) => (_db.select(_db.proxies)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Inserts or updates; returns the id. A non-null [password] replaces the saved one ('' removes it).
  Future<String> save(ProxiesCompanion data, {String? password}) async {
    final now = clock.now();
    final String id;
    if (data.id.present) {
      id = data.id.value;
      await (_db.update(_db.proxies)..where((p) => p.id.equals(id))).write(data.copyWith(updatedAt: Value(now)));
    } else {
      id = newId();
      await _db.into(_db.proxies).insert(data.copyWith(id: Value(id), createdAt: Value(now), updatedAt: Value(now)));
    }
    if (password != null) {
      password.isEmpty ? await _secrets.delete(passwordSecretId(id)) : await _secrets.write(passwordSecretId(id), password);
    }
    return id;
  }

  /// Hosts that go through [id] lose it (they connect directly again).
  Future<void> delete(String id) async {
    await (_db.delete(_db.proxies)..where((p) => p.id.equals(id))).go();
    await _secrets.delete(passwordSecretId(id));
  }

  Future<bool> hasPassword(String id) async => await _secrets.read(passwordSecretId(id)) != null;

  /// Hosts that connect through [id].
  Future<List<Connection>> usedBy(String id) =>
      (_db.select(_db.connections)..where((c) => c.proxyId.equals(id))).get();

  /// What the SOCKS5 client needs for [id], with its password; null when it is gone.
  Future<Socks5Proxy?> resolve(String id) async {
    final p = await get(id);
    if (p == null) return null;
    return Socks5Proxy(
      p.host,
      p.port,
      username: p.username.isEmpty ? null : p.username,
      password: p.username.isEmpty ? null : await _secrets.read(passwordSecretId(id)) ?? '',
    );
  }
}

final proxyRepositoryProvider =
    Provider((ref) => ProxyRepository(ref.watch(appDatabaseProvider), ref.watch(secretStoreProvider)));

final proxiesProvider = StreamProvider<List<Proxy>>((ref) => ref.watch(proxyRepositoryProvider).watchAll());
