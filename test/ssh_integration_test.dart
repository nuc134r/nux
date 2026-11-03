import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/background/keep_alive_hub.dart';
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
import 'package:nux/features/ssh/data/ssh_keep_alive.dart';
import 'package:nux/features/ssh/data/ssh_pool.dart';
import 'package:nux/features/ssh/domain/ssh_prompter.dart';

import 'helpers.dart';
import 'keep_alive_hub_test.dart' show RecordingKeepAlive;
import 'ssh_test_server.dart';

class FakePrompter implements SshPrompter {
  final hostKeys = <HostKeyQuestion>[];
  bool trust = true;
  String? passphraseAnswer;
  int passphraseAsked = 0;
  String? passwordAnswer;
  final passwordRetries = <bool>[];

  @override
  Future<bool> confirmHostKey(HostKeyQuestion q) async {
    hostKeys.add(q);
    return trust;
  }

  @override
  Future<SecretAnswer?> password({required String connectionName, required String address, required bool retry}) async {
    passwordRetries.add(retry);
    return passwordAnswer == null ? null : SecretAnswer(passwordAnswer!, remember: false);
  }

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
    // stdin is empty: a command that reads it ends instead of waiting.
    final cat = await backend.processRunner.run('cat; echo done').timeout(const Duration(seconds: 5));
    expect(cat.stdout, 'done\n');
    for (var i = 0; i < 20; i++) {
      expect((await backend.processRunner.run('exit 7')).exitCode, 7, reason: 'the exit status is never lost');
    }
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

  test('host fingerprints match ssh-keygen, and entries from older versions are upgraded', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final r = Process.runSync('ssh-keygen', ['-l', '-E', 'sha256', '-f', '${server!.dir.path}/host_ed25519.pub']);
    final expected = (r.stdout as String).split(' ')[1];
    final legacy = legacyHostFingerprint(Uint8List.fromList(utf8.encode(expected)));
    await known.trust('127.0.0.1', server!.port, 'ssh-ed25519', legacy);
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));
    final lease = await pool.acquire(c, prompter);
    lease.release();
    expect(prompter.hostKeys, isEmpty);
    expect((await known.forHost('127.0.0.1', server!.port)).single.fingerprint, expected);
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

  test('connections in use keep the app alive in the background; Disconnect all closes them', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final c = await addConnection(identityId: await identities.add(key, name: 'k'));
    final service = RecordingKeepAlive();
    final hub = KeepAliveHub(service, stopLabel: () => 'Disconnect all', idleText: () => '');
    final keepAlive = SshKeepAlive(pool, hub.slot('ssh'), title: (n) => '$n open', stopLabel: () => 'Disconnect all');
    addTearDown(keepAlive.dispose);

    final lease = await pool.acquire(c, prompter);
    final second = await pool.acquire(c, prompter);
    second.release();
    lease.release();
    await pumpEventQueue();
    expect(service.calls, ['start 1 open |  | Disconnect all', 'stop'], reason: 'one shared connection; idle ones do not count');

    final again = await pool.acquire(c, prompter);
    service.pressStop();
    await again.done.timeout(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(pool.inUseCount, 0);
    expect(service.calls.last, 'stop');
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

  // Last: failed logins can make newer sshd versions slow down this address.
  test('an unknown key is refused by the server, then a dismissed password prompt cancels', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final other = await generateKey(KeyAlgorithm.ed25519);
    final c = await addConnection(identityId: await identities.add(other, name: 'other'));
    await expectLater(
      pool.acquire(c, prompter),
      throwsA(isA<SshConnectException>().having((e) => e.failure, 'failure', SshFailure.cancelled)),
    );
    expect(prompter.passwordRetries, [false]);
  });

  test('a wrong password is asked again, then reported as an authentication failure', () async {
    if (skip()) return markTestSkipped('sshd not available');
    final other = await generateKey(KeyAlgorithm.ed25519);
    final c = await addConnection(identityId: await identities.add(other, name: 'other'));
    prompter.passwordAnswer = 'not-the-password';
    await expectLater(
      pool.acquire(c, prompter),
      throwsA(isA<SshConnectException>().having((e) => e.failure, 'failure', SshFailure.authFailed)),
    );
    expect(prompter.passwordRetries, [false, true, true]);
  });
}
