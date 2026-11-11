import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../core/log/log.dart';
import '../../settings/data/settings_repository.dart';

const _networksKey = 'zerotier.networks';
const _autoStartKey = 'zerotier.autoStart';

/// Members' ZeroTier addresses learned from traffic: `{"network id/IP": "address"}`.
const _membersKey = 'zerotier.members';

/// The app's ZeroTier node: started on demand (or with the app), remembers the joined networks.
class ZeroTierService extends ChangeNotifier {
  ZeroTierService(this._settings, this._log);

  final SettingsRepository _settings;
  final Log _log;
  ZeroTierNode get _node => ZeroTierNode.instance;

  bool _storageSet = false;
  StreamSubscription<ZeroTierNodeState>? _watch;

  /// Logs what libzt's guarded allocator holds (built with memory_guard, see pubspec.yaml).
  Timer? _guardLog;

  void _logGuard(String when) {
    final stats = ZeroTierMemoryGuard.stats();
    if (stats != null) _log.i('zerotier', 'Memory guard $when: $stats');
  }

  ZeroTierNodeState? _state;
  bool _starting = false;
  bool _disposed = false;

  /// The user turned the node off: connections and forwards do not start it again by themselves.
  bool _turnedOff = false;
  Completer<void> _stopped = Completer<void>();

  /// Networks the user joined (16 hex digits), in the order joined.
  List<String> networks = [];
  bool autoStart = false;

  bool get running => _node.running;
  bool get starting => _starting;

  /// Starting or stopping: the switch waits (libzt does not take a restart while it tears down).
  bool get busy => _starting || _stopping;
  bool _stopping = false;

  /// Starts and stops run one after the other, never interleaved.
  Future<void> _queue = Future.value();

  Future<void> _serial(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((Object _) {});
    return next;
  }

  ZeroTierNodeState? get state => _state;

  /// Completes when the running node stops.
  Future<void> get stopped => _stopped.future;

  ZeroTierNetworkState? network(String id) => _state?.networks.where((n) => n.idHex == id).firstOrNull;

  /// A joined network's addresses, routes, MAC and MTU; null while the node is off. Asks libzt each time.
  ZeroTierNetworkDetails? details(String id) {
    final parsed = parseNetworkId(id);
    return running && parsed != null ? _node.details(parsed) : null;
  }

  /// The peers the node knows; empty while it is off. Asks libzt each time.
  List<ZeroTierPeer> peers() => running ? _node.peers() : const [];

  int? get port => running ? _node.port : null;

  ZeroTierMemoryGuardStats? guardStats() => running ? ZeroTierMemoryGuard.stats() : null;

  Future<void> load() async {
    final s = await _settings.load();
    networks = [for (final n in (jsonDecode(s.values[_networksKey] ?? '[]') as List)) n as String];
    autoStart = s.values[_autoStartKey] == 'true';
    try {
      _members = {...(jsonDecode(s.values[_membersKey] ?? '{}') as Map).cast<String, String>()};
    } on Object {
      _members = {};
    }
    _notify();
  }

  Map<String, String> _members = {};
  Timer? _learnTimer;

  /// The ZeroTier address of the member at [ip] in network [networkId]: learned from traffic (see
  /// [learnMembers]) or, for RFC4193 and 6PLANE IPv6 addresses, read from the address itself.
  String? memberAddress(String networkId, String ip) =>
      _members['$networkId/${ip.trim().toLowerCase()}'] ?? zeroTierAddressFromIp(ip.trim(), networkId);

  /// Remembers which member has which IPv4 address, from the network stack's recent neighbors (it forgets
  /// them after a few minutes; nux keeps them, so a host stays recognised).
  Future<void> learnMembers() async {
    if (!running) return;
    var changed = false;
    for (final n in _node.neighbors()) {
      final key = '${n.networkId}/${n.ip}';
      if (_members[key] != n.address) {
        _members[key] = n.address;
        changed = true;
      }
    }
    if (!changed) return;
    _notify();
    await _settings.set(_membersKey, jsonEncode(_members));
  }

  Future<void> setAutoStart(bool v) async {
    autoStart = v;
    await _settings.set(_autoStartKey, '$v');
    _notify();
  }

  Future<void> start() {
    _turnedOff = false;
    return _serial(_start);
  }

  Future<void> _start() async {
    if (_node.running || _starting || _turnedOff) return;
    _starting = true;
    _notify();
    try {
      if (!_storageSet) {
        final dir = Directory('${(await getApplicationSupportDirectory()).path}/zerotier');
        await dir.create(recursive: true);
        _node.initStorage(dir.path);
        _storageSet = true;
      }
      await _node.start();
      if (_stopped.isCompleted) _stopped = Completer<void>();
      for (final n in networks) {
        _node.join(parseNetworkId(n)!);
      }
      _log.i('zerotier', 'Node started');
      _logGuard('on start');
      _guardLog?.cancel();
      _guardLog = Timer.periodic(const Duration(minutes: 10), (_) => _logGuard('while running'));
      _learnTimer?.cancel();
      _learnTimer = Timer.periodic(const Duration(seconds: 30), (_) => learnMembers());
      _watch = _node.watch().listen((s) {
        _state = s;
        _notify();
      });
    } finally {
      _starting = false;
      _notify();
    }
  }

  /// Turns the node off until [start] is called again.
  Future<void> stop() {
    _turnedOff = true;
    return _serial(_stop);
  }

  Future<void> _stop() async {
    // Already off: nothing to tear down (repeated taps used to restart libzt over and over).
    if (!_node.running) return;
    _stopping = true;
    unawaited(_watch?.cancel());
    _watch = null;
    _learnTimer?.cancel();
    _learnTimer = null;
    // What the stack knows now, before it is gone (the query runs at once, the save after).
    unawaited(learnMembers().catchError((Object _) {}));
    final stopping = _node.stop();
    _state = null;
    if (!_stopped.isCompleted) _stopped.complete();
    _notify();
    try {
      await stopping;
    } finally {
      _stopping = false;
      _guardLog?.cancel();
      _guardLog = null;
      _log.i('zerotier', 'Node stopped');
      _logGuard('after stop');
      _notify();
    }
  }

  Future<void> join(String id) async {
    if (!networks.contains(id)) {
      networks = [...networks, id];
      await _settings.set(_networksKey, jsonEncode(networks));
    }
    if (_node.running) _node.join(parseNetworkId(id)!);
    _notify();
  }

  Future<void> leave(String id) async {
    networks = networks.where((n) => n != id).toList();
    await _settings.set(_networksKey, jsonEncode(networks));
    if (_node.running) _node.leave(parseNetworkId(id)!);
    _notify();
  }

  /// Starts the node, joins [id] if needed and waits until the network has an address.
  /// Fails when the user turned ZeroTier off.
  Future<void> ensureNetwork(String id, {Duration timeout = const Duration(seconds: 60)}) async {
    if (_turnedOff) throw ZeroTierException('ZeroTier is turned off');
    await join(id);
    await start();
    try {
      await _node.waitUntilReady(networkId: parseNetworkId(id), timeout: timeout);
    } on TimeoutException {
      final n = network(id);
      throw ZeroTierException(switch (n?.status) {
        ZeroTierNetworkStatus.accessDenied => 'Not authorized on network $id',
        ZeroTierNetworkStatus.notFound => 'Network $id does not exist',
        _ when !(_state?.online ?? false) => 'ZeroTier is offline (no route to its root servers)',
        _ => 'Network $id is not ready (waiting for authorization or an address)',
      });
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watch?.cancel();
    _guardLog?.cancel();
    _learnTimer?.cancel();
    super.dispose();
  }
}

/// An SSH transport over a ZeroTier TCP connection.
class ZeroTierSshSocket implements SSHSocket {
  ZeroTierSshSocket(this._socket);

  final ZeroTierSocket _socket;

  @override
  Stream<Uint8List> get stream => _socket.stream;

  @override
  StreamSink<List<int>> get sink => _socket.sink;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() async {}
}

final zeroTierServiceProvider = Provider((ref) {
  final service = ZeroTierService(ref.watch(settingsRepositoryProvider), ref.watch(logProvider));
  ref.onDispose(service.dispose);
  service.load();
  return service;
});

/// Starts the node with the app when the user asked for that.
final zeroTierAutoStartProvider = FutureProvider<void>((ref) async {
  final service = ref.read(zeroTierServiceProvider);
  await service.load();
  if (service.autoStart && !kIsWeb) await service.start();
});
