import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../proxy/data/proxy_repository.dart';
import '../../proxy/domain/socks5.dart';
import '../../ssh/data/ssh_providers.dart';
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

/// The same through a saved SOCKS5 proxy: the time to connect through it (the proxy's round trip
/// included). A host behind a proxy is never probed directly.
typedef ProxyPinger = Future<Duration?> Function(String proxyId, String host, int port);

/// Overridden in tests (no real network).
final hostPingerProvider = Provider<HostPinger>((ref) => tcpPing);
final proxyPingerProvider = Provider<ProxyPinger>((ref) => (proxyId, host, port) async {
      final proxy = await ref.read(proxyRepositoryProvider).resolve(proxyId);
      if (proxy == null) return null;
      final watch = Stopwatch()..start();
      try {
        final c = await socks5Connect(proxy, host, port, timeout: const Duration(seconds: 5));
        watch.stop();
        c.socket.destroy();
        return watch.elapsed;
      } catch (_) {
        return null;
      }
    });
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

/// Round trip of an SSH-level request on an open connection (no new TCP connection: frequent probes
/// would fill the server's log with dropped pre-auth connections and can trip sshd's
/// PerSourcePenalties or fail2ban).
Future<Duration?> sshPing(SSHClient client, {Duration timeout = const Duration(seconds: 3)}) async {
  final watch = Stopwatch()..start();
  try {
    await client.ping().timeout(timeout);
    return watch.elapsed;
  } catch (_) {
    return null;
  }
}

/// What to ping: the saved connection (its open session, if any) and where it lives.
typedef PingTarget = ({String id, String host, int port, String? network, bool viaJump, String? proxyId});

/// The last ping of a host; the hosts list refreshes it by invalidating. Connected hosts are measured
/// over their SSH session (also behind jump hosts); others by a TCP connect to the SSH port, through
/// ZeroTier when the host is on a ZeroTier network that is up, through its proxy when it has one. (Not an error when unavailable:
/// Riverpod would keep retrying.)
final hostPingProvider = FutureProvider.autoDispose.family<Ping, PingTarget>((ref, t) async {
  final client = ref.read(sshPoolProvider).connectedClient(t.id);
  if (client != null) return Ping(await sshPing(client));
  if (t.viaJump) return const Ping.unavailable();
  if (t.network == null && t.proxyId != null) return Ping(await ref.watch(proxyPingerProvider)(t.proxyId!, t.host, t.port));
  if (t.network == null) return Ping(await ref.watch(hostPingerProvider)(t.host, t.port));
  final zerotier = ref.read(zeroTierServiceProvider);
  if (!zerotier.running || !(zerotier.network(t.network!)?.ready ?? false)) return const Ping.unavailable();
  return Ping(await ref.watch(zeroTierPingerProvider)(t.host, t.port));
});
