import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Overridden in tests (no real network).
final hostPingerProvider = Provider<HostPinger>((ref) => tcpPing);

/// The last ping of host:port; the hosts list refreshes it by invalidating.
final hostPingProvider = FutureProvider.autoDispose.family<Duration?, (String, int)>(
  (ref, target) => ref.watch(hostPingerProvider)(target.$1, target.$2),
);
