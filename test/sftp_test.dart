import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:nux/core/db/database.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/data/connection_repository.dart';
import 'package:nux/features/connections/data/known_hosts_repository.dart';
import 'package:nux/features/identities/data/identity_repository.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_material.dart';
import 'package:nux/features/ssh/data/sftp_file_system.dart';
import 'package:nux/features/ssh/data/ssh_connector.dart';
import 'package:test/test.dart';

import '../packages/nux_backend/test/file_system_contract.dart';
import 'helpers.dart';
import 'ssh_integration_test.dart' show FakePrompter;
import 'ssh_test_server.dart';

void main() {
  TestSshServer? server;
  late KeyMaterial key;
  late AppDatabase db;
  late SshConnector connector;
  late String connectionId;

  setUpAll(() async {
    server = await TestSshServer.start();
    key = await generateKey(KeyAlgorithm.ed25519);
    server?.authorize(key.publicLine());
    if (server == null) return;
    db = memoryDb();
    final secrets = MemorySecretStore();
    final connections = ConnectionRepository(db, secrets);
    final identities = IdentityRepository(db, secrets, connections);
    connector = SshConnector(connections: connections, identities: identities, knownHosts: KnownHostsRepository(db), log: Log());
    connectionId = await connections.save(ConnectionsCompanion.insert(
      name: 'sftp',
      host: '127.0.0.1',
      port: Value(server!.port),
      username: TestSshServer.user,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      identityIds: Value(encodeIdentityIds([await identities.add(key, name: 'k')])),
    ));
  });
  tearDownAll(() async {
    await server?.stop();
  });

  if (!File('/usr/sbin/sshd').existsSync()) {
    test('SFTP contract', () {}, skip: 'sshd not available');
    return;
  }

  fileSystemContract('SftpFileSystem', () async {
    final client = await connector.connect(connectionId, FakePrompter());
    final fs = SftpFileSystem(client);
    final dir = Directory.systemTemp.createTempSync('nux-sftp-');
    addTearDown(() async {
      await fs.close();
      client.close();
      dir.deleteSync(recursive: true);
    });
    expect(await fs.home(), isNotEmpty);
    return (fs, dir.path);
  });
}
