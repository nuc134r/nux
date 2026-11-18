import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/secure/secret_store.dart';

import 'helpers.dart';

void main() {
  testWidgets('a host behind a jump host says so under its address', (tester) async {
    final db = memoryDb();
    await tester.runAsync(() async {
      await insertSamples(db, MemorySecretStore());
      final now = DateTime.now();
      await db
          .into(db.connections)
          .insert(
            ConnectionsCompanion.insert(
              id: const Value('inner'),
              createdAt: now,
              updatedAt: now,
              name: 'Database box',
              host: '192.0.2.4',
              username: 'dev',
              jumpHostId: const Value('sample'),
            ),
          );
    });
    final c = ProviderContainer(overrides: testOverrides(db: db));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    expect(find.text('192.0.2.4 via build.example.com'), findsOneWidget);
    expect(find.text('build.example.com'), findsOneWidget, reason: 'a direct host shows just its address');

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
