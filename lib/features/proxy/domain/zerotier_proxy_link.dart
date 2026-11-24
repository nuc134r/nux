import 'dart:async';
import 'dart:math';

import 'package:zerotier_sockets/zerotier_sockets.dart' show ZeroTierUdpRelay;

import 'socks5.dart';

enum ProxyLinkState {
  /// Direct: no proxy.
  off,
  connecting,
  connected,

  /// The last attempt failed; another one is scheduled. Nothing goes out meanwhile.
  failed,
}

/// Keeps the ZeroTier node's traffic on a SOCKS5 UDP association: makes it, hands the relay to the node,
/// and makes it again when the proxy drops it. While there is none the node is held (sends nothing),
/// so nothing leaks past the proxy. Plain Dart; the node is reached through [setRelay].
class ZeroTierProxyLink {
  ZeroTierProxyLink({
    required this.setRelay,
    this.associate = socks5UdpAssociate,
    this.onChange,
    this.log,
    this.firstRetry = const Duration(seconds: 2),
    this.maxRetry = const Duration(minutes: 1),
  });

  /// Points the node somewhere (`ZeroTierNode.instance.udpRelay = …` in the app).
  final void Function(ZeroTierUdpRelay? relay) setRelay;
  final Future<Socks5UdpAssociation> Function(Socks5Proxy proxy, {Duration timeout}) associate;
  final void Function()? onChange;
  final void Function(String message)? log;
  final Duration firstRetry;
  final Duration maxRetry;

  ProxyLinkState state = ProxyLinkState.off;

  /// Why the last attempt failed.
  Object? error;

  /// `ip:port` of the relay in use.
  String? relay;

  Socks5Proxy? _proxy;
  Socks5UdpAssociation? _association;
  Timer? _retry;
  int _failures = 0;

  /// Bumped on every change, so an attempt that finishes late is dropped.
  int _generation = 0;

  /// Null until the first [setRelay]: the node starts out direct.
  ZeroTierUdpRelay? _relay;

  void _set(ZeroTierUdpRelay? r) {
    if (r == _relay) return;
    _relay = r;
    setRelay(r);
  }

  /// Sends the node through [proxy] (null: directly), waiting for the first attempt. A failure is not
  /// thrown: [state] says it, and attempts go on.
  Future<void> use(Socks5Proxy? proxy) async {
    _drop();
    _proxy = proxy;
    _failures = 0;
    error = null;
    if (proxy == null) {
      relay = null;
      state = ProxyLinkState.off;
      _set(null);
      onChange?.call();
      return;
    }
    // Held until the association is there: no packet goes out directly meanwhile.
    _set(ZeroTierUdpRelay.hold);
    await _attempt(_generation);
  }

  /// Ends the association (the node stopped). The node stays held when a proxy was in use, so a node
  /// started again sends nothing until [use] made a new one.
  void close() {
    _drop();
    if (_proxy != null) {
      _set(ZeroTierUdpRelay.hold);
      state = ProxyLinkState.connecting;
      relay = null;
    }
    onChange?.call();
  }

  void _drop() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _association?.close();
    _association = null;
  }

  Future<void> _attempt(int generation) async {
    final proxy = _proxy;
    if (proxy == null) return;
    state = ProxyLinkState.connecting;
    onChange?.call();
    try {
      final a = await associate(proxy, timeout: const Duration(seconds: 15));
      if (generation != _generation) {
        a.close();
        return;
      }
      _association = a;
      _failures = 0;
      error = null;
      relay = '${a.relayAddress.address}:${a.relayPort}';
      state = ProxyLinkState.connected;
      _set(ZeroTierUdpRelay.socks5(a.relayAddress.address, a.relayPort));
      log?.call('UDP association made, relay $relay');
      onChange?.call();
      unawaited(a.done.then((_) {
        if (generation != _generation) return;
        log?.call('The proxy ended the UDP association');
        _association = null;
        relay = null;
        _set(ZeroTierUdpRelay.hold);
        _schedule(generation, Duration.zero);
      }));
    } catch (e) {
      if (generation != _generation) return;
      _failures++;
      error = e;
      relay = null;
      state = ProxyLinkState.failed;
      _set(ZeroTierUdpRelay.hold);
      final wait = Duration(
        milliseconds: min(maxRetry.inMilliseconds, firstRetry.inMilliseconds * pow(2, _failures - 1).toInt()),
      );
      log?.call('UDP association failed ($e); again in ${wait.inSeconds} s');
      onChange?.call();
      _schedule(generation, wait);
    }
  }

  void _schedule(int generation, Duration wait) {
    _retry?.cancel();
    _retry = Timer(wait, () {
      if (generation == _generation) _attempt(generation);
    });
  }

  void dispose() => _drop();
}
