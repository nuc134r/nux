import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../domain/host_key_check.dart';

class KnownHostsRepository {
  KnownHostsRepository(this._db);

  final AppDatabase _db;

  Future<List<KnownHost>> forHost(String host, int port) => (_db.select(_db.knownHosts)
        ..where((k) => k.host.equals(host.toLowerCase()) & k.port.equals(port)))
      .get();

  Future<HostKeyStatus> check(String host, int port, String keyType, String fingerprint) async =>
      checkHostKey((await forHost(host, port)).map((k) => KnownHostKey(k.keyType, k.fingerprint)), keyType, fingerprint);

  /// Trusts a key, replacing any previously trusted key of the same type for this host.
  Future<void> trust(String host, int port, String keyType, String fingerprint) async {
    final now = clock.now();
    await _db.transaction(() async {
      await (_db.delete(_db.knownHosts)
            ..where((k) => k.host.equals(host.toLowerCase()) & k.port.equals(port) & k.keyType.equals(keyType)))
          .go();
      await _db.into(_db.knownHosts).insert(KnownHostsCompanion.insert(
            host: host.toLowerCase(),
            port: port,
            keyType: keyType,
            fingerprint: fingerprint,
            createdAt: now,
            updatedAt: now,
            lastSeenAt: Value(now),
          ));
    });
  }

  Future<void> touch(String host, int port, String keyType) => (_db.update(_db.knownHosts)
        ..where((k) => k.host.equals(host.toLowerCase()) & k.port.equals(port) & k.keyType.equals(keyType)))
      .write(KnownHostsCompanion(lastSeenAt: Value(clock.now())));

  Stream<List<KnownHost>> watchAll() =>
      (_db.select(_db.knownHosts)..orderBy([(k) => OrderingTerm(expression: k.host), (k) => OrderingTerm(expression: k.port)]))
          .watch();

  Future<void> delete(String id) => (_db.delete(_db.knownHosts)..where((k) => k.id.equals(id))).go();
}

final knownHostsRepositoryProvider = Provider((ref) => KnownHostsRepository(ref.watch(appDatabaseProvider)));

final knownHostsProvider = StreamProvider<List<KnownHost>>((ref) => ref.watch(knownHostsRepositoryProvider).watchAll());
