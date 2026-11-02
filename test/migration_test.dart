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
}
