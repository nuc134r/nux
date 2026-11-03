import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/app_info.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/identities/data/device_name.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_material.dart';
import 'package:nux/features/ssh/data/ssh_providers.dart';
import 'package:nux/features/ssh/domain/ssh_prompter.dart';

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
}

/// Overrides that keep tests off the device: in-memory database and secrets, fixed version.
List<Override> testOverrides({AppDatabase? db, SecretStore? secrets, SshPrompter? prompter}) => [
      appDatabaseProvider.overrideWithValue(db ?? memoryDb()),
      secretStoreProvider.overrideWithValue(secrets ?? MemorySecretStore()),
      appVersionProvider.overrideWith((ref) async => '0.1.0+1'),
      sshPrompterProvider.overrideWithValue(prompter ?? const RefusingPrompter()),
      deviceNameProvider.overrideWith((ref) async => 'Pixel-9'),
    ];

/// Says no to everything (no dialogs in widget tests).
class RefusingPrompter implements SshPrompter {
  const RefusingPrompter();

  @override
  Future<bool> confirmHostKey(HostKeyQuestion question) async => false;

  @override
  Future<SecretAnswer?> password({required String connectionName, required String address, required bool retry}) async => null;

  @override
  Future<SecretAnswer?> passphrase({required String identityName, required bool retry}) async => null;

  @override
  Future<List<String>?> keyboardInteractive({
    required String address,
    required String name,
    required String instruction,
    required List<KeyboardInteractivePrompt> prompts,
  }) async =>
      null;

  @override
  Future<bool> authenticateUser({required String reason}) async => false;
}

/// A connection and a key with the id `sample` (used by routes with ids in the smoke test).
Future<void> insertSamples(AppDatabase db, SecretStore secrets) async {
  final now = DateTime(2026);
  final KeyMaterial key = await generateKey(KeyAlgorithm.ed25519, comment: 'sample@example.com');
  await secrets.write('key:sample', key.toOpenSsh());
  await db.into(db.identities).insert(IdentitiesCompanion.insert(
        id: const Value('sample'),
        createdAt: now,
        updatedAt: now,
        name: 'Sample key',
        algorithm: key.algorithm,
        bits: key.bits,
        publicKey: key.publicLine(),
        fingerprint: sha256Fingerprint(key.publicBlob),
      ));
  await db.into(db.connections).insert(ConnectionsCompanion.insert(
        id: const Value('sample'),
        createdAt: now,
        updatedAt: now,
        name: 'Build server',
        host: 'build.example.com',
        username: 'dev',
        identityIds: const Value('["sample"]'),
        groupName: const Value('Work'),
      ));
  await db.into(db.forwardRules).insert(ForwardRulesCompanion.insert(
        id: const Value('sample'),
        createdAt: now,
        updatedAt: now,
        connectionId: 'sample',
        kind: 'local',
        label: const Value('Database'),
        bindPort: 15432,
        targetHost: const Value('db.internal.example.com'),
        targetPort: const Value(5432),
      ));
  await db.into(db.knownHosts).insert(KnownHostsCompanion.insert(
        createdAt: now,
        updatedAt: now,
        host: 'build.example.com',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ));
}

/// Pumps until Drift streams and animations have settled (pumpAndSettle would spin on progress indicators).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
