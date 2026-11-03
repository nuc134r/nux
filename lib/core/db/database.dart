import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

export 'tables.dart' show newId, SyncedTable;

part 'database.g.dart';

@DriftDatabase(tables: [AppSettings, Connections, Identities, KnownHosts, Bookmarks, ForwardRules])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(driftDatabase(name: 'nux'));

  // After a schema change: bump this, add the step below, dump the schema and regenerate the
  // migration test helpers (see CLAUDE.md).
  @override
  int get schemaVersion => 5;

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
            await m.alterTable(TableMigration(forwardRules, newColumns: [forwardRules.zerotierNetwork]));
          }
          // Tables created above already have the newest columns; only older ones need them added.
          if (from >= 2 && from < 5) await m.addColumn(connections, connections.zerotierNetwork);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});
