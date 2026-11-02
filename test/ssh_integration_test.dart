import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/data/connection_repository.dart';
import 'package:nux/features/connections/data/known_hosts_repository.dart';
import 'package:nux/features/connections/domain/host_key_check.dart';
import 'package:nux/features/identities/data/identity_repository.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_material.dart';
import 'package:nux/features/ssh/data/ssh_backend.dart';
import 'package:nux/features/ssh/data/ssh_connector.dart';
import 'package:nux/features/ssh/data/ssh_pool.dart';
import 'package:nux/features/ssh/domain/ssh_prompter.dart';

import 'helpers.dart';
import 'ssh_test_server.dart';

class FakePrompter implements SshPrompter {
  final hostKeys = <HostKeyQuestion>[];
  bool trust = true;
  String? passphraseAnswer;
  int passphraseAsked = 0;

  @override
  Future<bool> confirmHostKey(HostKeyQuestion q) async {
    hostKeys.add(q);
    return trust;
  }

  @override
  Future<SecretAnswer?> password({required String connectionName, required String address, required bool retry}) async => null;

  @override
  Future<SecretAnswer?> passphrase({required String identityName, required bool retry}) async {
    passphraseAsked++;
    return passphraseAnswer == null ? null : SecretAnswer(passphraseAnswer!, remember: true);
  }

  @override
  Future<List<String>?> keyboardInteractive({
    required String address,
    required String name,
    required String instruction,
    required List<KeyboardInteractivePrompt> prompts,
  }) async =>
      null;

  @override
  Future<bool> authenticateUser({required String reason}) async => true;
}

void main() {
  TestSshServer? server;
  late AppDatabase db;
  late ConnectionRepository connections;
  late IdentityRepository identities;
  late KnownHostsRepository known;
  late SshConnector connector;
  late SshPool pool;
  late FakePrompter prompter;
  late KeyMaterial key;

  setUpAll(() async {
    server = await TestSshServer.start();
    key = await generateKey(KeyAlgorithm.ed25519, comment: 'nux-test');
    server?.authorize(key.publicLine());
  });
  tearDownAll(() => server?.stop());

  setUp(() {
    db = memoryDb();
    final secrets = MemorySecretStore();
    connections = ConnectionRepository(db, secrets);
    identities = IdentityRepository(db, secrets, connections);
    known = KnownHostsRepository(db);
    final log = Log();
    connector = SshConnector(connections: connections, identities: identities, knownHosts: known, log: log);
    pool = SshPool(connector, log, idleTimeout: Duration.zero);
    prompter = FakePrompter();
  });
  tearDown(() async {
    pool.dispose();
    await db.close();
  });

  Future<String> addConnection({required String identityId, String? jumpHostId, String host = '127.0.0.1'}) =>
      connections.save(ConnectionsCompanion.insert(
        name: 'test',
        host: host,
        port: Value(server!.port),
        username: TestSshServer.user,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        identityIds: Value(encodeIdentityIds([identityId])),
        jumpHostId: Value(jumpHostId),
      ));

  bool skip() => server == null;

  test('trusts the host key on first use, then remembers it', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));

    final lease = await pool.acquire(c, prompter);
    expect(prompter.hostKeys.single.status, HostKeyStatus.unknown);
    expect(prompter.hostKeys.single.fingerprint, startsWith('SHA256:'));
    expect(pool.state(c), SshState.connected);
    lease.release();
    await lease.done;
    await pumpEventQueue();
    expect(pool.state(c), SshState.disconnected);

    final again = await pool.acquire(c, prompter);
    expect(prompter.hostKeys, hasLength(1), reason: 'the key is trusted now');
    again.release();
  });

  test('exec and pty work through the backend', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));
    final lease = await pool.acquire(c, prompter);
    addTearDown(lease.release);
    final backend = SshBackend(id: c, displayName: 'test', client: lease.client);

    final ok = await backend.processRunner.run('echo "hello world"; echo oops >&2');
    expect(ok.stdout, 'hello world\n');
    expect(ok.stderr, 'oops\n');
    expect(ok.exitCode, 0);
    final fail = await backend.processRunner.run('exit 3');
    expect(fail.exitCode, 3);
    final cd = await backend.processRunner.run('pwd', workingDirectory: '/tmp', environment: {'GREETING': "it's"});
    expect(cd.stdout.trim(), '/tmp');
    expect((await backend.processRunner.run(r'echo "$GREETING"', environment: {'GREETING': "it's"})).stdout, "it's\n");

    final pty = await backend.ptyHost.open(columns: 100, rows: 30);
    final out = StringBuffer();
    final sub = pty.output.listen((d) => out.write(utf8.decode(d, allowMalformed: true)));
    pty.write(Uint8List.fromList(utf8.encode('echo "term=\$TERM cols=\$(tput cols)"; exit\n')));
    await pty.done.timeout(const Duration(seconds: 10));
    await sub.cancel();
    expect(out.toString(), contains('term=xterm-256color cols=100'));
  });

  test('a changed host key is reported and can be refused', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));
    await known.trust('127.0.0.1', server!.port, 'ssh-ed25519', 'SHA256:somethingElse');
    prompter.trust = false;
    await expectLater(
      pool.acquire(c, prompter),
      throwsA(isA<SshConnectException>().having((e) => e.failure, 'failure', SshFailure.hostKeyRejected)),
    );
    expect(prompter.hostKeys.single.status, HostKeyStatus.changed);
    expect(prompter.hostKeys.single.knownFingerprints.single, 'ssh-ed25519 SHA256:somethingElse');
    expect(pool.state(c), SshState.disconnected);
  });

  test('an unknown key is refused by the server', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final other = await generateKey(KeyAlgorithm.ed25519);
    final c = await addConnection(identityId: await identities.add(other, name: 'other'));
    await expectLater(
      pool.acquire(c, prompter),
      throwsA(isA<SshConnectException>().having((e) => e.failure, 'failure', SshFailure.authFailed)),
    );
  });

  test('passphrase-protected keys ask once when remembered', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k', passphrase: 'pw'));
    prompter.passphraseAnswer = 'pw';
    final lease = await pool.acquire(c, prompter);
    lease.release();
    await lease.done;
    await pumpEventQueue();
    (await pool.acquire(c, prompter)).release();
    expect(prompter.passphraseAsked, 1);
  });

  test('connects through a jump host', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final id = await identities.add(key, name: 'k');
    final jump = await addConnection(identityId: id);
    // The target is reached from the jump host, so "localhost" there is the same test server.
    final target = await addConnection(identityId: id, jumpHostId: jump, host: 'localhost');
    final lease = await pool.acquire(target, prompter);
    addTearDown(lease.release);
    final r = await SshBackend(id: target, displayName: 't', client: lease.client).processRunner.run('echo via-jump');
    expect(r.stdout, 'via-jump\n');
    expect(prompter.hostKeys.map((q) => q.host), ['127.0.0.1', 'localhost']);
  });

  test('concurrent acquires share one connection', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));
    final leases = await Future.wait([pool.acquire(c, prompter), pool.acquire(c, prompter)]);
    expect(identical(leases[0].client, leases[1].client), isTrue);
    expect(prompter.hostKeys, hasLength(1));
    leases[0].release();
    await pumpEventQueue();
    expect(pool.state(c), SshState.connected, reason: 'still leased');
    leases[1].release();
  });
}
