import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/db/database.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/connections/data/connection_repository.dart';
import 'package:nux/features/connections/data/known_hosts_repository.dart';
import 'package:nux/features/forwarding/domain/forward_rule.dart';
import 'package:nux/features/forwarding/domain/forwarder.dart';
import 'package:nux/features/identities/data/identity_repository.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_material.dart';
import 'package:nux/features/ssh/data/ssh_connector.dart';

import 'helpers.dart';
import 'ssh_integration_test.dart' show FakePrompter;
import 'ssh_test_server.dart';

/// Answers every line with `echo: line`.
Future<ServerSocket> echoServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((s) => s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) => s.write('echo: $line\n')));
  return server;
}

Future<String> roundTrip(Socket s, String line) async {
  final reply = s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).first;
  s.write('$line\n');
  return reply.timeout(const Duration(seconds: 10));
}

void main() {
  TestSshServer? server;
  SSHClient? client;
  late ServerSocket echo;
  late AppDatabase db;

  setUpAll(() async {
    echo = await echoServer();
    server = await TestSshServer.start();
    if (server == null) return;
    final key = await generateKey(KeyAlgorithm.ed25519);
    server!.authorize(key.publicLine());
    db = memoryDb();
    final secrets = MemorySecretStore();
    final connections = ConnectionRepository(db, secrets);
    final identities = IdentityRepository(db, secrets, connections);
    final id = await connections.save(ConnectionsCompanion.insert(
      name: 'fwd',
      host: '127.0.0.1',
      port: Value(server!.port),
      username: TestSshServer.user,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      identityIds: Value(encodeIdentityIds([await identities.add(key, name: 'k')])),
    ));
    client = await SshConnector(connections: connections, identities: identities, knownHosts: KnownHostsRepository(db), log: Log())
        .connect(id, FakePrompter());
  });
  tearDownAll(() async {
    client?.close();
    await echo.close();
    await server?.stop();
  });

  test('local forward (-L) carries traffic both ways and counts it', () async {
    if (client == null) return markTestSkipped('sshd not available');
    final fwd = await startForward(client!, kind: ForwardKind.local, bindHost: '127.0.0.1', bindPort: 0, targetHost: '127.0.0.1', targetPort: echo.port);
    addTearDown(fwd.close);
    final s = await Socket.connect('127.0.0.1', fwd.port);
    expect(await roundTrip(s, 'hello'), 'echo: hello');
    await s.close();
    expect(fwd.stats.connections, 1);
    expect(fwd.stats.bytesOut, 6);
    expect(fwd.stats.bytesIn, 12);
  });

  test('a taken local port is reported as such', () async {
    if (client == null) return markTestSkipped('sshd not available');
    final taken = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(taken.close);
    await expectLater(
      startForward(client!, kind: ForwardKind.local, bindHost: '127.0.0.1', bindPort: taken.port, targetHost: '127.0.0.1', targetPort: 1),
      throwsA(isA<ForwardException>().having((e) => e.error, 'error', ForwardError.portInUse)),
    );
  });

  test('remote forward (-R) brings server connections to this device', () async {
    if (client == null) return markTestSkipped('sshd not available');
    final probe = await ServerSocket.bind('127.0.0.1', 0);
    final port = probe.port;
    await probe.close();
    final fwd = await startForward(client!, kind: ForwardKind.remote, bindHost: '127.0.0.1', bindPort: port, targetHost: '127.0.0.1', targetPort: echo.port);
    addTearDown(fwd.close);
    // The "server side" is this machine too: connect to the port sshd now listens on.
    final s = await Socket.connect('127.0.0.1', port);
    expect(await roundTrip(s, 'from server'), 'echo: from server');
    await s.close();
  });

  test('dynamic forward (-D) is a SOCKS5 proxy', () async {
    if (client == null) return markTestSkipped('sshd not available');
    final fwd = await startForward(client!, kind: ForwardKind.dynamic, bindHost: '127.0.0.1', bindPort: 0);
    addTearDown(fwd.close);
    final s = await Socket.connect('127.0.0.1', fwd.port);
    final replies = StreamIterator(s);
    Future<List<int>> read(int n) async {
      final out = <int>[];
      while (out.length < n && await replies.moveNext()) {
        out.addAll(replies.current);
      }
      return out;
    }

    s.add([5, 1, 0]); // version 5, one method: no auth
    expect(await read(2), [5, 0]);
    s.add([5, 1, 0, 1, 127, 0, 0, 1, echo.port >> 8, echo.port & 0xff]); // CONNECT 127.0.0.1:echo
    final reply = await read(10);
    expect(reply.take(2), [5, 0]);
    s.write('via socks\n');
    final line = await read(16);
    expect(utf8.decode(line), 'echo: via socks\n');
    await s.close();
    expect(fwd.stats.connections, 1);
  });

  test('conflicts', () {
    ForwardRule rule(String id, String conn, ForwardKind k, int port, {String host = '127.0.0.1'}) => ForwardRule(
          id: id,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          connectionId: conn,
          zerotierNetwork: null,
          kind: k.name,
          label: '',
          bindHost: host,
          bindPort: port,
          targetHost: 'db',
          targetPort: 5432,
          autoStart: false,
          sortOrder: 0,
        );
    final a = rule('a', 'c1', ForwardKind.local, 8080);
    expect(conflictingRule(rule('b', 'c2', ForwardKind.local, 8080, host: 'localhost'), [a])?.id, 'a');
    expect(conflictingRule(rule('b', 'c2', ForwardKind.dynamic, 8080, host: '0.0.0.0'), [a])?.id, 'a');
    expect(conflictingRule(rule('b', 'c2', ForwardKind.local, 8081), [a]), isNull);
    expect(conflictingRule(rule('b', 'c1', ForwardKind.remote, 8080), [a]), isNull, reason: 'remote listens on the server');
    expect(conflictingRule(rule('c', 'c2', ForwardKind.remote, 9000), [rule('d', 'c1', ForwardKind.remote, 9000)]), isNull,
        reason: 'different servers');
    expect(a.describe(), '8080 → db:5432');
    expect(rule('x', 'c', ForwardKind.dynamic, 1080).describe(), 'SOCKS 1080');
  });
}
