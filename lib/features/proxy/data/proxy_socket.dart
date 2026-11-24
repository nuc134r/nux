import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../domain/socks5.dart';

/// An SSH transport over a TCP connection through a SOCKS5 proxy.
class Socks5SshSocket implements SSHSocket {
  Socks5SshSocket(this._connection);

  final Socks5Connection _connection;

  @override
  Stream<Uint8List> get stream => _connection.stream;

  @override
  StreamSink<List<int>> get sink => _connection.socket;

  @override
  Future<void> get done => _connection.socket.done;

  @override
  Future<void> close() => _connection.socket.close();

  @override
  void destroy() => _connection.socket.destroy();

  @override
  Future<void> flush() => _connection.socket.flush();
}
