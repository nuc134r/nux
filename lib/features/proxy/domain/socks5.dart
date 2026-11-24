/// A SOCKS5 client (RFC 1928) with username/password authentication (RFC 1929): CONNECT for TCP and
/// UDP ASSOCIATE for UDP. Plain Dart, no Flutter.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Where a SOCKS5 proxy is and how to log in to it.
class Socks5Proxy {
  const Socks5Proxy(this.host, this.port, {this.username, this.password});

  final String host;
  final int port;

  /// Both set: username/password authentication; otherwise none.
  final String? username;
  final String? password;

  bool get hasCredentials => (username ?? '').isNotEmpty;

  @override
  String toString() => 'Socks5Proxy($host:$port${hasCredentials ? ', with login' : ''})';
}

enum Socks5Error {
  /// The proxy itself could not be reached (DNS, refused, timed out).
  unreachable,

  /// The proxy wants a login nux does not have, or no method both sides know.
  noAcceptableMethod,

  /// The username or password was rejected.
  authFailed,

  /// The proxy answered, but not like a SOCKS5 server.
  protocol,

  /// Reply 1: general failure.
  generalFailure,

  /// Reply 2: the proxy's rules do not allow it.
  notAllowed,

  /// Reply 3.
  networkUnreachable,

  /// Reply 4.
  hostUnreachable,

  /// Reply 5: the target refused the connection.
  connectionRefused,

  /// Reply 6.
  ttlExpired,

  /// Reply 7: e.g. a proxy without UDP ASSOCIATE.
  commandNotSupported,

  /// Reply 8.
  addressTypeNotSupported,
}

class Socks5Exception implements Exception {
  const Socks5Exception(this.error, this.message);

  final Socks5Error error;
  final String message;

  @override
  String toString() => 'Socks5Exception(${error.name}): $message';
}

const _replyErrors = {
  1: (Socks5Error.generalFailure, 'General failure of the proxy'),
  2: (Socks5Error.notAllowed, 'Not allowed by the proxy'),
  3: (Socks5Error.networkUnreachable, 'Network unreachable from the proxy'),
  4: (Socks5Error.hostUnreachable, 'Host unreachable from the proxy'),
  5: (Socks5Error.connectionRefused, 'Connection refused'),
  6: (Socks5Error.ttlExpired, 'TTL expired'),
  7: (Socks5Error.commandNotSupported, 'Command not supported by the proxy'),
  8: (Socks5Error.addressTypeNotSupported, 'Address type not supported by the proxy'),
};

/// A TCP connection through a SOCKS5 proxy, ready for data. Bytes the target sent along with the
/// proxy's reply (an SSH server speaks first) are at the start of [stream].
class Socks5Connection {
  Socks5Connection._(this.socket, this.stream, this.boundAddress, this.boundPort);

  /// The connection to the proxy: write to it, close or destroy it. Do not listen to it: use [stream].
  final Socket socket;
  final Stream<Uint8List> stream;

  /// The address and port the proxy connects from (as it reported them).
  final String boundAddress;
  final int boundPort;
}

/// A UDP relay a SOCKS5 proxy opened for this client (UDP ASSOCIATE). It lasts while [control] is open.
class Socks5UdpAssociation {
  Socks5UdpAssociation._(this.control, this.relayAddress, this.relayPort, this._done);

  /// The TCP connection the association belongs to.
  final Socket control;

  /// Where to send datagrams wrapped by [encodeSocks5Udp] (an IP address).
  final InternetAddress relayAddress;
  final int relayPort;
  final Future<void> _done;

  /// Completes when the proxy closes the association (or [close] is called).
  Future<void> get done => _done;

  void close() => control.destroy();
}

/// Connects to [host]:[port] through [proxy]. Host names are resolved by the proxy.
Future<Socks5Connection> socks5Connect(
  Socks5Proxy proxy,
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final session = await _Session.open(proxy, timeout);
  try {
    final (address, boundPort) = await session.request(1, host, port).timeout(timeout);
    return Socks5Connection._(session.socket, session.rest(), address, boundPort);
  } catch (e) {
    session.socket.destroy();
    throw _timeout(e);
  }
}

/// Asks [proxy] for a UDP relay (UDP ASSOCIATE). The relay's address replaces an unspecified one in the
/// reply (`0.0.0.0`) with the proxy's.
Future<Socks5UdpAssociation> socks5UdpAssociate(
  Socks5Proxy proxy, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final session = await _Session.open(proxy, timeout);
  try {
    // The client's address is not known (behind NAT): all zeros, as RFC 1928 says.
    final (address, port) = await session.request(3, '0.0.0.0', 0).timeout(timeout);
    InternetAddress relay;
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null) {
      relay = (await InternetAddress.lookup(address)).first;
    } else if (parsed.isAnyAddress()) {
      relay = session.socket.remoteAddress;
    } else {
      relay = parsed;
    }
    // The association ends with its TCP connection; anything the proxy says on it is ignored.
    final done = Completer<void>();
    session.rest().listen(
      (_) {},
      onDone: () => done.isCompleted ? null : done.complete(),
      onError: (Object _) => done.isCompleted ? null : done.complete(),
      cancelOnError: true,
    );
    return Socks5UdpAssociation._(session.socket, relay, port, done.future);
  } catch (e) {
    session.socket.destroy();
    throw _timeout(e);
  }
}

/// Logs in to [proxy] and asks for a UDP relay: throws when the proxy cannot be used at all, else tells
/// whether it relays UDP (ZeroTier needs that; hosts only need CONNECT).
Future<({bool udp})> socks5Check(Socks5Proxy proxy, {Duration timeout = const Duration(seconds: 15)}) async {
  try {
    (await socks5UdpAssociate(proxy, timeout: timeout)).close();
    return (udp: true);
  } on Socks5Exception catch (e) {
    if (e.error == Socks5Error.commandNotSupported || e.error == Socks5Error.notAllowed) return (udp: false);
    rethrow;
  }
}

Object _timeout(Object e) =>
    e is TimeoutException ? const Socks5Exception(Socks5Error.unreachable, 'The proxy did not answer in time') : e;

extension on InternetAddress {
  bool isAnyAddress() => rawAddress.every((b) => b == 0);
}

/// The handshake on one TCP connection: reads replies from a buffer, as a reply and the target's first
/// bytes can come in one chunk.
class _Session {
  _Session(this.socket) {
    _sub = socket.listen(
      (data) {
        _buffer.add(data);
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      onDone: () {
        _closed = true;
        _wake();
      },
    );
  }

  final Socket socket;
  late final StreamSubscription<Uint8List> _sub;
  final _buffer = BytesBuilder(copy: false);
  Completer<void>? _waiting;
  Object? _error;
  bool _closed = false;

  void _wake() {
    final w = _waiting;
    _waiting = null;
    w?.complete();
  }

  static Future<_Session> open(Socks5Proxy proxy, Duration timeout) async {
    final Socket socket;
    try {
      socket = await Socket.connect(proxy.host, proxy.port, timeout: timeout);
    } on SocketException catch (e) {
      throw Socks5Exception(Socks5Error.unreachable, e.osError?.message ?? e.message);
    }
    socket.setOption(SocketOption.tcpNoDelay, true);
    final s = _Session(socket);
    try {
      await s._greet(proxy).timeout(timeout);
    } catch (e) {
      socket.destroy();
      throw _timeout(e);
    }
    return s;
  }

  Future<Uint8List> _read(int n) async {
    while (_buffer.length < n) {
      if (_error != null) throw Socks5Exception(Socks5Error.unreachable, '$_error');
      if (_closed) throw const Socks5Exception(Socks5Error.protocol, 'The proxy closed the connection');
      await (_waiting = Completer<void>()).future;
    }
    final all = _buffer.takeBytes();
    if (all.length > n) _buffer.add(Uint8List.sublistView(all, n));
    return Uint8List.sublistView(all, 0, n);
  }

  Future<void> _greet(Socks5Proxy proxy) async {
    final login = proxy.hasCredentials;
    socket.add(login ? [5, 2, 0, 2] : [5, 1, 0]);
    final reply = await _read(2);
    if (reply[0] != 5) throw const Socks5Exception(Socks5Error.protocol, 'Not a SOCKS5 proxy');
    switch (reply[1]) {
      case 0:
        return;
      case 2 when login:
        final user = utf8.encode(proxy.username!);
        final pass = utf8.encode(proxy.password ?? '');
        if (user.length > 255 || pass.length > 255) {
          throw const Socks5Exception(Socks5Error.authFailed, 'Username or password longer than 255 bytes');
        }
        socket.add([1, user.length, ...user, pass.length, ...pass]);
        final status = await _read(2);
        if (status[1] != 0) throw const Socks5Exception(Socks5Error.authFailed, 'The proxy rejected the login');
      case 2:
        throw const Socks5Exception(Socks5Error.noAcceptableMethod, 'The proxy needs a username and password');
      default:
        throw const Socks5Exception(Socks5Error.noAcceptableMethod, 'The proxy accepts none of the login methods');
    }
  }

  /// Sends a request (1 CONNECT, 3 UDP ASSOCIATE) and returns the bound address and port.
  Future<(String, int)> request(int command, String host, int port) async {
    socket.add([5, command, 0, ...encodeSocks5Address(host, port)]);
    final head = await _read(4);
    if (head[0] != 5) throw const Socks5Exception(Socks5Error.protocol, 'Not a SOCKS5 reply');
    if (head[1] != 0) {
      final (error, message) = _replyErrors[head[1]] ?? (Socks5Error.generalFailure, 'Proxy error ${head[1]}');
      throw Socks5Exception(error, message);
    }
    final String address;
    switch (head[3]) {
      case 1:
        address = InternetAddress.fromRawAddress(await _read(4)).address;
      case 4:
        address = InternetAddress.fromRawAddress(await _read(16)).address;
      case 3:
        final n = (await _read(1))[0];
        address = utf8.decode(await _read(n), allowMalformed: true);
      default:
        throw const Socks5Exception(Socks5Error.protocol, 'Unknown address type in the reply');
    }
    final p = await _read(2);
    return (address, p[0] << 8 | p[1]);
  }

  /// What comes after the handshake: what is buffered, then the rest of the socket. The socket is paused
  /// until the stream is listened to, so nothing that arrives in between is lost.
  Stream<Uint8List> rest() {
    _sub.pause();
    late final StreamController<Uint8List> out;
    out = StreamController<Uint8List>(
      onListen: () {
        final leftover = _buffer.takeBytes();
        if (leftover.isNotEmpty) out.add(leftover);
        if (_error != null) out.addError(_error!);
        if (_closed) {
          out.close();
          return;
        }
        _sub
          ..onData(out.add)
          ..onError(out.addError)
          ..onDone(out.close)
          ..resume();
      },
      onPause: _sub.pause,
      onResume: _sub.resume,
      onCancel: _sub.cancel,
    );
    return out.stream;
  }
}

/// ATYP, address and port of a SOCKS5 request: an IP literal as such, anything else as a domain name
/// (resolved by the proxy).
List<int> encodeSocks5Address(String host, int port) {
  final ip = InternetAddress.tryParse(host);
  final portBytes = [port >> 8 & 0xff, port & 0xff];
  if (ip != null) {
    return [ip.type == InternetAddressType.IPv4 ? 1 : 4, ...ip.rawAddress, ...portBytes];
  }
  final name = utf8.encode(host);
  if (name.isEmpty || name.length > 255) throw ArgumentError.value(host, 'host', 'not a host name');
  return [3, name.length, ...name, ...portBytes];
}

/// A datagram for a SOCKS5 UDP relay: header (RSV, FRAG 0, address, port) and [data].
Uint8List encodeSocks5Udp(String host, int port, List<int> data) =>
    Uint8List.fromList([0, 0, 0, ...encodeSocks5Address(host, port), ...data]);

/// A datagram from a SOCKS5 UDP relay: who sent it and its data. Null for fragments and malformed ones.
({String host, int port, Uint8List data})? decodeSocks5Udp(Uint8List d) {
  if (d.length < 4 || d[2] != 0) return null;
  final int start;
  final String host;
  switch (d[3]) {
    case 1 when d.length >= 10:
      host = InternetAddress.fromRawAddress(Uint8List.sublistView(d, 4, 8)).address;
      start = 8;
    case 4 when d.length >= 22:
      host = InternetAddress.fromRawAddress(Uint8List.sublistView(d, 4, 20)).address;
      start = 20;
    case 3 when d.length >= 5 && d.length >= 7 + d[4]:
      host = utf8.decode(Uint8List.sublistView(d, 5, 5 + d[4]), allowMalformed: true);
      start = 5 + d[4];
    default:
      return null;
  }
  return (host: host, port: d[start] << 8 | d[start + 1], data: Uint8List.sublistView(d, start + 2));
}

/// A short reason for a failure through a proxy, for logs and errors.
String proxyErrorText(Object? e) => switch (e) {
      Socks5Exception(:final message) => message,
      null => 'unknown error',
      _ => '$e',
    };
