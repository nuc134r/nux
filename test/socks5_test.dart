import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/proxy/domain/socks5.dart';

import 'socks5_test_server.dart';

/// A TCP server that speaks first (like an SSH server's banner), then echoes.
Future<ServerSocket> bannerEcho() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((s) {
    s.add(utf8.encode('HELLO\n'));
    s.listen(s.add, onDone: s.destroy);
  });
  return server;
}

Future<String> readUntil(Stream<Uint8List> stream, String end) async {
  final text = StringBuffer();
  await for (final d in stream) {
    text.write(utf8.decode(d));
    if (text.toString().endsWith(end)) break;
  }
  return text.toString();
}

void main() {
  late ServerSocket echo;
  setUp(() async => echo = await bannerEcho());
  tearDown(() => echo.close());

  test('CONNECT without a login: the banner the target sent is not lost, even when read late', () async {
    final socks = await TestSocks5Server.start();
    addTearDown(socks.close);
    final c = await socks5Connect(Socks5Proxy('127.0.0.1', socks.port), '127.0.0.1', echo.port);
    // Listened to late: what arrived meanwhile waits.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final reader = StreamIterator(c.stream);
    final banner = StringBuffer();
    while (!banner.toString().endsWith('\n') && await reader.moveNext()) {
      banner.write(utf8.decode(reader.current));
    }
    expect(banner.toString(), 'HELLO\n');
    c.socket.add(utf8.encode('ping\n'));
    expect(await reader.moveNext(), isTrue);
    expect(utf8.decode(reader.current), 'ping\n');
    await reader.cancel();
    c.socket.destroy();
    expect(socks.connects, ['127.0.0.1:${echo.port}']);
  });

  test('host names go to the proxy unresolved; username and password log in', () async {
    final socks = await TestSocks5Server.start(username: 'nux', password: 'pässword');
    addTearDown(socks.close);
    final c = await socks5Connect(
      Socks5Proxy('127.0.0.1', socks.port, username: 'nux', password: 'pässword'),
      'localhost',
      echo.port,
    );
    expect(await readUntil(c.stream, '\n'), 'HELLO\n');
    c.socket.destroy();
    expect(socks.logins, ['nux']);
    expect(socks.connects, ['localhost:${echo.port}']);
  });

  test('login problems and proxy replies become clear errors', () async {
    final socks = await TestSocks5Server.start(username: 'nux', password: 'secret');
    addTearDown(socks.close);
    Matcher fails(Socks5Error e) => throwsA(isA<Socks5Exception>().having((x) => x.error, 'error', e));
    await expectLater(
      socks5Connect(Socks5Proxy('127.0.0.1', socks.port, username: 'nux', password: 'nope'), 'localhost', 1),
      fails(Socks5Error.authFailed),
    );
    await expectLater(socks5Connect(Socks5Proxy('127.0.0.1', socks.port), 'localhost', 1), fails(Socks5Error.noAcceptableMethod));

    final open = await TestSocks5Server.start();
    addTearDown(open.close);
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(socks5Connect(Socks5Proxy('127.0.0.1', open.port), '127.0.0.1', port), fails(Socks5Error.connectionRefused));

    final strict = await TestSocks5Server.start(replyFirst: 2);
    addTearDown(strict.close);
    await expectLater(socks5Connect(Socks5Proxy('127.0.0.1', strict.port), 'example.com', 22), fails(Socks5Error.notAllowed));

    // Nothing listens there.
    await expectLater(socks5Connect(Socks5Proxy('127.0.0.1', port), 'example.com', 22), fails(Socks5Error.unreachable));
    // Not a SOCKS5 server (the echo server greets with text).
    await expectLater(socks5Connect(Socks5Proxy('127.0.0.1', echo.port), 'example.com', 22), fails(Socks5Error.protocol));
  });

  test('UDP ASSOCIATE: datagrams go through the relay both ways; the association ends with its connection', () async {
    final socks = await TestSocks5Server.start(username: 'nux', password: 'secret');
    addTearDown(socks.close);
    final target = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(target.close);
    target.listen((e) {
      final d = target.receive();
      if (d != null) target.send([...utf8.encode('re:'), ...d.data], d.address, d.port);
    });

    final proxy = Socks5Proxy('127.0.0.1', socks.port, username: 'nux', password: 'secret');
    expect((await socks5Check(proxy)).udp, isTrue);
    final a = await socks5UdpAssociate(proxy);
    expect(a.relayAddress.address, '127.0.0.1', reason: 'the reply said 0.0.0.0: the proxy\'s own address');

    final client = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(client.close);
    final got = Completer<({String host, int port, Uint8List data})>();
    client.listen((e) {
      final d = client.receive();
      final m = d == null ? null : decodeSocks5Udp(d.data);
      if (m != null && !got.isCompleted) got.complete(m);
    });
    client.send(encodeSocks5Udp('127.0.0.1', target.port, utf8.encode('hi')), a.relayAddress, a.relayPort);
    final reply = await got.future.timeout(const Duration(seconds: 5));
    expect((reply.host, reply.port, utf8.decode(reply.data)), ('127.0.0.1', target.port, 're:hi'));
    expect(socks.relayed, ['127.0.0.1:${target.port}']);

    socks.dropAll();
    await a.done.timeout(const Duration(seconds: 5));
  });

  test('a proxy without UDP still works for hosts', () async {
    final socks = await TestSocks5Server.start(udp: false);
    addTearDown(socks.close);
    expect((await socks5Check(Socks5Proxy('127.0.0.1', socks.port))).udp, isFalse);
    await expectLater(
      socks5UdpAssociate(Socks5Proxy('127.0.0.1', socks.port)),
      throwsA(isA<Socks5Exception>().having((e) => e.error, 'error', Socks5Error.commandNotSupported)),
    );
  });

  test('UDP headers', () {
    expect(encodeSocks5Udp('192.0.2.1', 9993, [7]), [0, 0, 0, 1, 192, 0, 2, 1, 0x27, 0x09, 7]);
    expect(encodeSocks5Udp('2001:db8::1', 1, [])[3], 4);
    expect(encodeSocks5Udp('example.com', 80, [])[3], 3);
    final v6 = decodeSocks5Udp(encodeSocks5Udp('2001:db8::1', 9993, [1, 2]))!;
    expect('${v6.host} ${v6.port} ${v6.data}', '2001:db8::1 9993 [1, 2]');
    final name = decodeSocks5Udp(encodeSocks5Udp('example.com', 53, [9]))!;
    expect('${name.host} ${name.port} ${name.data}', 'example.com 53 [9]');
    expect(decodeSocks5Udp(Uint8List.fromList([0, 0, 1, 1, 192, 0, 2, 1, 0, 1])), isNull, reason: 'a fragment');
    expect(decodeSocks5Udp(Uint8List.fromList([0, 0, 0, 1, 192])), isNull);
  });
}
