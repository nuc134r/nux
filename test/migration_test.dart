import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/db/database.dart';

import 'generated_migrations/schema.dart';

// Schemas are dumped in `drift_schemas/`; see CLAUDE.md for the commands to run after a schema change.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches the latest dump', () async {
    final db = AppDatabase(DatabaseConnection((await verifier.schemaAt(GeneratedHelper.versions.last)).newConnection().executor));
    addTearDown(db.close);
    expect(db.schemaVersion, GeneratedHelper.versions.last, reason: 'dump the schema after bumping schemaVersion');
    await verifier.migrateAndValidate(db, db.schemaVersion);
  });

  for (final from in GeneratedHelper.versions.where((v) => v < GeneratedHelper.versions.last)) {
    test('upgrades from v$from to the current schema', () async {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, db.schemaVersion);
      await db.close();
    });
  }

  test('v6 attaches ZeroTier rules to hosts (an existing one, or a new one)', () async {
    final schema = await verifier.schemaAt(5);
    final old = schema.rawDatabase;
    const t = "'2026-01-01T00:00:00.000'";
    old.execute('INSERT INTO connections (id, created_at, updated_at, name, host, username, zerotier_network) '
        "VALUES ('nas', $t, $t, 'NAS', '192.0.2.10', 'me', 'a1b2c3d4e5f60708')");
    for (final (id, kind, host) in [('a', 'zerotierTcp', '192.0.2.10'), ('b', 'zerotierUdp', '192.0.2.20')]) {
      old.execute('INSERT INTO forward_rules (id, created_at, updated_at, zerotier_network, kind, bind_port, target_host, target_port) '
          "VALUES ('$id', $t, $t, 'a1b2c3d4e5f60708', '$kind', 27015, '$host', 27015)");
    }
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 6);
    final rules = {for (final r in await db.select(db.forwardRules).get()) r.id: r};
    expect(rules['a']!.connectionId, 'nas');
    expect((rules['a']!.kind, rules['a']!.targetHost, rules['a']!.tcp, rules['a']!.udp), ('local', 'localhost', true, false));
    final created = await (db.select(db.connections)..where((c) => c.id.equals(rules['b']!.connectionId!))).getSingle();
    expect((created.host, created.zerotierNetwork), ('192.0.2.20', 'a1b2c3d4e5f60708'));
    expect((rules['b']!.tcp, rules['b']!.udp), (false, true));
  });
}
