import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import 'forward_rule.dart';

/// Traffic through one running forward.
class ForwardStats {
  /// Bytes from the far side to the client that connected (download direction).
  int bytesIn = 0;

  /// Bytes from the client that connected to the far side.
  int bytesOut = 0;

  /// Connections accepted since the forward started.
  int connections = 0;

  /// Connections open right now.
  int open = 0;

  /// Connections that could not reach their target.
  int failed = 0;
}

enum ForwardError {
  /// The listening port is taken on this device.
  portInUse,

  /// Listening on that address is not allowed here (e.g. a port below 1024 on Android).
  bindDenied,

  /// The server refused to listen (AllowTcpForwarding, GatewayPorts or a taken port there).
  remoteRefused,
  other,
}

class ForwardException implements Exception {
  const ForwardException(this.error, this.message);

  final ForwardError error;
  final String message;

  @override
  String toString() => 'ForwardException(${error.name}): $message';
}

/// A forward that is listening.
abstract class RunningForward {
  ForwardStats get stats;

  /// The port actually listened on (useful when 0 was asked for).
  int get port;

  Future<void> close();
}

/// Several forwards run as one rule (TCP and UDP on the same port); traffic is added up.
class CombinedForward implements RunningForward {
  CombinedForward(this.parts);

  final List<RunningForward> parts;

  @override
  ForwardStats get stats {
    final sum = ForwardStats();
    for (final p in parts) {
      sum
        ..bytesIn += p.stats.bytesIn
        ..bytesOut += p.stats.bytesOut
        ..connections += p.stats.connections
        ..open += p.stats.open
        ..failed += p.stats.failed;
    }
    return sum;
  }

  @override
  int get port => parts.first.port;

  @override
  Future<void> close() async {
    for (final p in parts) {
      await p.close();
    }
  }
}

/// Starts a forward of [kind] on an authenticated [client]. [onChange] is called on traffic and
/// connection changes (callers throttle their UI updates).
Future<RunningForward> startForward(
  SSHClient client, {
  required ForwardKind kind,
  required String bindHost,
  required int bindPort,
  String targetHost = '',
  int targetPort = 0,
  void Function()? onChange,
}) async {
  switch (kind) {
    case ForwardKind.local:
      final server = await _bind(bindHost, bindPort);
      return _LocalForward(client, server, targetHost, targetPort, onChange);
    case ForwardKind.remote:
      final SSHRemoteForward? remote;
      try {
        remote = await client.forwardRemote(host: bindHost, port: bindPort);
      } catch (e) {
        throw ForwardException(ForwardError.remoteRefused, '$e');
      }
      if (remote == null) throw const ForwardException(ForwardError.remoteRefused, 'The server refused to listen');
      return _RemoteForward(client, remote, targetHost, targetPort, onChange);
    case ForwardKind.dynamic:
      final stats = ForwardStats();
      try {
        final socks = await startDynamicForward(
          bindHost: bindHost,
          bindPort: bindPort,
          options: const SSHDynamicForwardOptions(),
          dial: (host, port) async {
            stats.connections++;
            onChange?.call();
            try {
              return await client.forwardLocal(host, port);
            } catch (_) {
              stats.failed++;
              onChange?.call();
              rethrow;
            }
          },
        );
        return _DynamicForward(socks, stats);
      } on SocketException catch (e) {
        throw forwardBindError(e);
      }
  }
}

Future<ServerSocket> _bind(String host, int port) async {
  try {
    return await ServerSocket.bind(host, port);
  } on SocketException catch (e) {
    throw forwardBindError(e);
  }
}

/// A [ForwardException] for a failed local bind.
ForwardException forwardBindError(SocketException e) {
  final code = e.osError?.errorCode;
  // EADDRINUSE: 98 Linux/Android, 48 macOS, 10048 Windows. EACCES: 13.
  // Dart refuses a second bind in the same process before asking the OS (no error code then).
  if (code == 98 || code == 48 || code == 10048 || '${e.message} ${e.osError?.message}'.contains('shared flag')) {
    return ForwardException(ForwardError.portInUse, e.message);
  }
  if (code == 13 || code == 10013) return ForwardException(ForwardError.bindDenied, e.message);
  return ForwardException(ForwardError.other, e.osError?.message ?? e.message);
}

/// Copies both ways between a local socket and an SSH channel, counting bytes.
void _pipe(Socket socket, SSHForwardChannel channel, ForwardStats stats, void Function()? onChange) {
  stats.open++;
  onChange?.call();
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    stats.open--;
    onChange?.call();
    socket.destroy();
    channel.close();
  }

  socket.listen(
    (data) {
      stats.bytesOut += data.length;
      channel.sink.add(data);
      onChange?.call();
    },
    onDone: close,
    onError: (Object _) => close(),
    cancelOnError: true,
  );
  channel.stream.listen(
    (data) {
      stats.bytesIn += data.length;
      socket.add(data);
      onChange?.call();
    },
    onDone: close,
    onError: (Object _) => close(),
    cancelOnError: true,
  );
}

class _LocalForward implements RunningForward {
  _LocalForward(SSHClient client, this._server, String host, int port, void Function()? onChange) {
    _sub = _server.listen((socket) async {
      stats.connections++;
      try {
        final channel = await client.forwardLocal(host, port);
        _pipe(socket, channel, stats, onChange);
      } catch (_) {
        stats.failed++;
        socket.destroy();
        onChange?.call();
      }
    });
  }

  final ServerSocket _server;
  late final StreamSubscription<Socket> _sub;

  @override
  final stats = ForwardStats();

  @override
  int get port => _server.port;

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _server.close();
  }
}

class _RemoteForward implements RunningForward {
  _RemoteForward(this._client, this._remote, String host, int port, void Function()? onChange) {
    _sub = _remote.connections.listen((channel) async {
      stats.connections++;
      try {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
        _pipe(socket, channel, stats, onChange);
      } catch (_) {
        stats.failed++;
        channel.close();
        onChange?.call();
      }
    });
  }

  final SSHClient _client;
  final SSHRemoteForward _remote;
  late final StreamSubscription<SSHForwardChannel> _sub;

  @override
  final stats = ForwardStats();

  @override
  int get port => _remote.port;

  @override
  Future<void> close() async {
    await _sub.cancel();
    if (!_client.isClosed) {
      try {
        await _client.cancelForwardRemote(_remote);
      } catch (_) {}
    }
  }
}

class _DynamicForward implements RunningForward {
  _DynamicForward(this._socks, this.stats);

  final SSHDynamicForward _socks;

  @override
  final ForwardStats stats;

  @override
  int get port => _socks.port;

  @override
  Future<void> close() => _socks.close();
}
