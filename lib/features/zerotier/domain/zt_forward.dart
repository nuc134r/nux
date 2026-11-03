import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../forwarding/domain/forwarder.dart';

/// A local TCP port whose connections go to a ZeroTier address.
Future<RunningForward> startZeroTierTcpForward({
  required String bindHost,
  required int bindPort,
  required String targetHost,
  required int targetPort,
  void Function()? onChange,
}) async {
  final ServerSocket server;
  try {
    server = await ServerSocket.bind(bindHost, bindPort);
  } on SocketException catch (e) {
    throw forwardBindError(e);
  }
  return _ZtTcpForward(server, targetHost, targetPort, onChange);
}

class _ZtTcpForward implements RunningForward {
  _ZtTcpForward(this._server, String host, int port, void Function()? onChange) {
    _sub = _server.listen((socket) async {
      stats.connections++;
      try {
        final zt = await ZeroTierSocket.connect(host, port);
        _pipe(socket, zt, onChange);
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

  void _pipe(Socket socket, ZeroTierSocket zt, void Function()? onChange) {
    stats.open++;
    onChange?.call();
    var closed = false;
    void close() {
      if (closed) return;
      closed = true;
      stats.open--;
      onChange?.call();
      socket.destroy();
      zt.destroy();
    }

    socket.listen((d) {
      stats.bytesOut += d.length;
      zt.add(d);
      onChange?.call();
    }, onDone: close, onError: (Object _) => close(), cancelOnError: true);
    zt.stream.listen((d) {
      stats.bytesIn += d.length;
      socket.add(d);
      onChange?.call();
    }, onDone: close, onError: (Object _) => close(), cancelOnError: true);
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _server.close();
  }
}

/// A local UDP port relayed to a ZeroTier address. Each local sender gets its own ZeroTier socket so
/// replies find their way back; idle senders are forgotten after [idle].
Future<RunningForward> startZeroTierUdpForward({
  required String bindHost,
  required int bindPort,
  required String targetHost,
  required int targetPort,
  void Function()? onChange,
  Duration idle = const Duration(minutes: 2),
}) async {
  final RawDatagramSocket local;
  try {
    local = await RawDatagramSocket.bind(bindHost, bindPort);
  } on SocketException catch (e) {
    throw forwardBindError(e);
  }
  return _ZtUdpForward(local, targetHost, targetPort, onChange, idle);
}

class _Peer {
  _Peer(this.socket, this.address, this.port);

  final ZeroTierDatagramSocket socket;
  final InternetAddress address;
  final int port;
  DateTime last = DateTime.now();
}

class _ZtUdpForward implements RunningForward {
  _ZtUdpForward(this._local, this._host, this._port, this._onChange, this._idle) {
    _sub = _local.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = _local.receive()) != null) {
        _fromLocal(d!);
      }
    });
    _sweeper = Timer.periodic(const Duration(seconds: 30), (_) => _sweep());
  }

  final RawDatagramSocket _local;
  final String _host;
  final int _port;
  final void Function()? _onChange;
  final Duration _idle;
  late final StreamSubscription<RawSocketEvent> _sub;
  late final Timer _sweeper;
  final Map<String, _Peer> _peers = {};

  @override
  final stats = ForwardStats();

  @override
  int get port => _local.port;

  void _fromLocal(Datagram d) {
    final key = '${d.address.address}:${d.port}';
    var peer = _peers[key];
    if (peer == null) {
      try {
        final zt = ZeroTierDatagramSocket.bind('0.0.0.0', 0);
        peer = _Peer(zt, d.address, d.port);
        _peers[key] = peer;
        stats.connections++;
        stats.open = _peers.length;
        final p = peer;
        zt.listen((packet) {
          p.last = DateTime.now();
          stats.bytesIn += packet.data.length;
          _local.send(packet.data, p.address, p.port);
          _onChange?.call();
        });
      } catch (_) {
        stats.failed++;
        _onChange?.call();
        return;
      }
    }
    peer.last = DateTime.now();
    try {
      peer.socket.send(Uint8List.fromList(d.data), _host, _port);
      stats.bytesOut += d.data.length;
    } catch (_) {
      stats.failed++;
    }
    _onChange?.call();
  }

  void _sweep() {
    final cutoff = DateTime.now().subtract(_idle);
    _peers.removeWhere((_, p) {
      final old = p.last.isBefore(cutoff);
      if (old) p.socket.close();
      return old;
    });
    stats.open = _peers.length;
    _onChange?.call();
  }

  @override
  Future<void> close() async {
    _sweeper.cancel();
    await _sub.cancel();
    _local.close();
    for (final p in _peers.values) {
      p.socket.close();
    }
    _peers.clear();
  }
}
