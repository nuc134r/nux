import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nux/features/proxy/domain/socks5.dart';

/// A small SOCKS5 server on localhost for tests: no authentication or username/password, CONNECT and
/// UDP ASSOCIATE (relayed for real). Records what it was asked.
class TestSocks5Server {
  TestSocks5Server._(this._server, this.username, this.password, this.udp, this.replyFirst) {
    _server.listen(_serve);
  }

  static Future<TestSocks5Server> start({String? username, String? password, bool udp = true, int? replyFirst}) async =>
      TestSocks5Server._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), username, password, udp, replyFirst);

  final ServerSocket _server;
  final String? username;
  final String? password;

  /// UDP ASSOCIATE is supported (else answered with "command not supported").
  final bool udp;

  /// Answer every request with this reply code instead of doing it.
  final int? replyFirst;

  int get port => _server.port;

  /// `host:port` of each CONNECT, in order.
  final connects = <String>[];
  final logins = <String>[];

  /// Requests of any kind (also refused ones).
  int requests = 0;
  int associations = 0;

  /// Datagrams relayed out (destination `host:port`).
  final relayed = <String>[];

  /// Datagrams relayed back to the client (source `host:port`).
  final returned = <String>[];
  final _open = <Socket>{};
  final _relays = <RawDatagramSocket>{};

  /// Closes every connection (ends UDP associations), keeps listening.
  void dropAll() {
    for (final s in _open.toList()) {
      s.destroy();
    }
  }

  Future<void> close() async {
    dropAll();
    for (final r in _relays) {
      r.close();
    }
    await _server.close();
  }

  Future<void> _serve(Socket client) async {
    _open.add(client);
    final reader = _Reader(client);
    try {
      final greeting = await reader.read(2);
      final methods = await reader.read(greeting[1]);
      final needLogin = username != null;
      if (needLogin && !methods.contains(2) || !needLogin && !methods.contains(0)) {
        client.add([5, 0xff]);
        await client.close();
        return;
      }
      client.add([5, needLogin ? 2 : 0]);
      if (needLogin) {
        await reader.read(1);
        final user = utf8.decode(await reader.read((await reader.read(1))[0]));
        final pass = utf8.decode(await reader.read((await reader.read(1))[0]));
        logins.add(user);
        final ok = user == username && pass == password;
        client.add([1, ok ? 0 : 1]);
        if (!ok) {
          await client.close();
          return;
        }
      }
      final head = await reader.read(4);
      final String host = switch (head[3]) {
        1 => InternetAddress.fromRawAddress(await reader.read(4)).address,
        4 => InternetAddress.fromRawAddress(await reader.read(16)).address,
        _ => utf8.decode(await reader.read((await reader.read(1))[0])),
      };
      final p = await reader.read(2);
      final port = p[0] << 8 | p[1];
      requests++;
      if (replyFirst != null) {
        client.add([5, replyFirst!, 0, 1, 0, 0, 0, 0, 0, 0]);
        await client.close();
        return;
      }
      switch (head[1]) {
        case 1:
          connects.add('$host:$port');
          final Socket target;
          try {
            target = await Socket.connect(host == 'localhost' ? '127.0.0.1' : host, port);
          } on SocketException {
            client.add([5, 5, 0, 1, 0, 0, 0, 0, 0, 0]);
            await client.close();
            return;
          }
          _open.add(target);
          client.add([5, 0, 0, 1, 127, 0, 0, 1, target.port >> 8, target.port & 0xff]);
          reader.rest.listen(target.add, onDone: target.destroy, onError: (Object _) => target.destroy());
          target.listen(client.add, onDone: client.destroy, onError: (Object _) => client.destroy());
        case 3 when udp:
          associations++;
          final relay = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
          final out = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          RawDatagramSocket? out6;
          try {
            out6 = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
          } on SocketException {
            // No IPv6 here: those datagrams are dropped.
          }
          _relays.addAll([relay, out, ?out6]);
          InternetAddress? clientAddress;
          int? clientPort;
          relay.listen((e) {
            final d = relay.receive();
            if (d == null) return;
            clientAddress = d.address;
            clientPort = d.port;
            final m = decodeSocks5Udp(d.data);
            if (m == null) return;
            relayed.add('${m.host}:${m.port}');
            final to = InternetAddress(m.host);
            try {
              (to.type == InternetAddressType.IPv6 ? out6 : out)?.send(m.data, to, m.port);
            } on SocketException {
              // Unreachable from here: dropped, as a real relay would.
            }
          });
          for (final o in [out, ?out6]) {
            o.listen((e) {
              final d = o.receive();
              if (d == null || clientAddress == null) return;
              returned.add('${d.address.address}:${d.port}');
              relay.send(encodeSocks5Udp(d.address.address, d.port, d.data), clientAddress!, clientPort!);
            });
          }
          // Reply 0.0.0.0: "the address you reached me at".
          client.add([5, 0, 0, 1, 0, 0, 0, 0, relay.port >> 8, relay.port & 0xff]);
          void end() {
            relay.close();
            out.close();
            out6?.close();
          }

          reader.rest.listen((_) {}, onDone: end, onError: (Object _) => end());
        default:
          client.add([5, 7, 0, 1, 0, 0, 0, 0, 0, 0]);
          await client.close();
      }
    } on Object {
      client.destroy();
    }
  }
}

class _Reader {
  _Reader(Socket socket) {
    _sub = socket.listen((d) {
      if (_rest != null) {
        _rest!.add(d);
        return;
      }
      _buffer.add(d);
      _waiting?.complete();
      _waiting = null;
    }, onDone: () {
      _closed = true;
      _rest?.close();
      _waiting?.complete();
      _waiting = null;
    });
  }

  late final StreamSubscription<Uint8List> _sub;
  final _buffer = BytesBuilder(copy: false);
  Completer<void>? _waiting;
  bool _closed = false;
  StreamController<Uint8List>? _rest;

  Future<Uint8List> read(int n) async {
    while (_buffer.length < n) {
      if (_closed) throw const SocketException('closed');
      await (_waiting = Completer<void>()).future;
    }
    final all = _buffer.takeBytes();
    _buffer.add(Uint8List.sublistView(all, n));
    return Uint8List.sublistView(all, 0, n);
  }

  /// Everything after the request.
  Stream<Uint8List> get rest {
    final c = _rest = StreamController<Uint8List>(onCancel: _sub.cancel);
    final left = _buffer.takeBytes();
    if (left.isNotEmpty) c.add(left);
    if (_closed) c.close();
    return c.stream;
  }
}
