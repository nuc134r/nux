import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

export 'tables.dart' show newId, SyncedTable;

part 'database.g.dart';

@DriftDatabase(tables: [AppSettings, Connections, Identities, KnownHosts, Bookmarks, ForwardRules, Workspaces])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(driftDatabase(name: 'nux'));

  // After a schema change: bump this, add the step below, dump the schema and regenerate the
  // migration test helpers (see CLAUDE.md).
  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(connections);
            await m.createTable(identities);
            await m.createTable(knownHosts);
          }
          if (from < 3) await m.createTable(bookmarks);
          if (from < 4) await m.createTable(forwardRules);
          if (from >= 4 && from < 5) {
            // connectionId became nullable (ZeroTier rules have no SSH host): rebuild the table.
            await m.alterTable(TableMigration(forwardRules, newColumns: [forwardRules.zerotierNetwork, forwardRules.tcp, forwardRules.udp]));
          }
          // Tables created above already have the newest columns; only older ones need them added.
          if (from >= 2 && from < 5) await m.addColumn(connections, connections.zerotierNetwork);
          // The v5 rebuild above already gave the table its newest columns.
          if (from == 5) {
            await m.addColumn(forwardRules, forwardRules.tcp);
            await m.addColumn(forwardRules, forwardRules.udp);
          }
          if (from >= 4 && from < 6) await _attachZeroTierRules();
          if (from < 7) await m.createTable(workspaces);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Forwardings belong to hosts since v6: a ZeroTier rule (network + address, no host) becomes a local
/// rule on the host with that address in that network, creating the host when there is none.
extension on AppDatabase {
  Future<void> _attachZeroTierRules() async {
    final rules = await customSelect(
      "SELECT id, kind, zerotier_network, target_host FROM forward_rules WHERE kind IN ('zerotierTcp', 'zerotierUdp')",
    ).get();
    final now = Variable<DateTime>(DateTime.now());
    for (final r in rules) {
      final network = r.read<String?>('zerotier_network') ?? '';
      final address = r.read<String>('target_host');
      final found = await customSelect(
        'SELECT id FROM connections WHERE zerotier_network = ? AND host = ? LIMIT 1',
        variables: [Variable(network), Variable(address)],
      ).getSingleOrNull();
      var hostId = found?.read<String>('id');
      if (hostId == null) {
        hostId = newId();
        await customInsert(
          'INSERT INTO connections (id, created_at, updated_at, name, host, username, zerotier_network) '
          "VALUES (?, ?, ?, ?, ?, '', ?)",
          variables: [Variable(hostId), now, now, Variable(address), Variable(address), Variable(network)],
        );
      }
      final udp = r.read<String>('kind') == 'zerotierUdp';
      await customUpdate(
        "UPDATE forward_rules SET kind = 'local', connection_id = ?, target_host = 'localhost', tcp = ?, udp = ?, "
        'updated_at = ? WHERE id = ?',
        variables: [Variable(hostId), Variable(!udp), Variable(udp), now, Variable(r.read<String>('id'))],
      );
    }
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});
