import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../zerotier/data/zerotier_service.dart';

/// Round-trip time of a TCP connect to [host]:[port], or null when it fails or times out.
/// (ICMP needs privileges on Android; the SSH port is what matters anyway.)
typedef HostPinger = Future<Duration?> Function(String host, int port);

Future<Duration?> tcpPing(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
  final watch = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    watch.stop();
    socket.destroy();
    return watch.elapsed;
  } catch (_) {
    return null;
  }
}

/// The same over ZeroTier (the host is only reachable through the node).
Future<Duration?> zeroTierPing(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
  final watch = Stopwatch()..start();
  try {
    final socket = await ZeroTierSocket.connect(host, port, timeout: timeout);
    watch.stop();
    socket.destroy();
    return watch.elapsed;
  } catch (_) {
    return null;
  }
}

/// Overridden in tests (no real network).
final hostPingerProvider = Provider<HostPinger>((ref) => tcpPing);
final zeroTierPingerProvider = Provider<HostPinger>((ref) => zeroTierPing);

/// What the hosts list shows: a round-trip time, no reply, or nothing (cannot be measured now: the
/// host's ZeroTier network is not up, and the node is not started just to ping).
class Ping {
  const Ping(this.rtt) : measured = true;
  const Ping.unavailable()
      : rtt = null,
        measured = false;

  /// Null when the port did not answer.
  final Duration? rtt;
  final bool measured;
}

/// The last ping of host:port, over [network] when it is a ZeroTier host; the hosts list refreshes it
/// by invalidating. (Not an error when unavailable: Riverpod would keep retrying.)
final hostPingProvider = FutureProvider.autoDispose.family<Ping, (String, int, String?)>((ref, target) async {
  final (host, port, network) = target;
  if (network == null) return Ping(await ref.watch(hostPingerProvider)(host, port));
  final zerotier = ref.read(zeroTierServiceProvider);
  if (!zerotier.running || !(zerotier.network(network)?.ready ?? false)) return const Ping.unavailable();
  return Ping(await ref.watch(zeroTierPingerProvider)(host, port));
});
