import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/app_info.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/secure/secret_store.dart';

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}

/// Overrides that keep tests off the device: in-memory database and secrets, fixed version.
List<Override> testOverrides({AppDatabase? db, SecretStore? secrets}) => [
      appDatabaseProvider.overrideWithValue(db ?? memoryDb()),
      secretStoreProvider.overrideWithValue(secrets ?? MemorySecretStore()),
      appVersionProvider.overrideWith((ref) async => '0.1.0+1'),
    ];

/// Pumps until Drift streams and animations have settled (pumpAndSettle would spin on progress indicators).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
