import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../../core/background/keep_alive.dart';
import 'forward_rule.dart';
import 'forwarder.dart';

enum ForwardState { stopped, starting, active, reconnecting, failed }

/// A connection lease held by a running forward.
class ForwardLease {
  ForwardLease({required this.client, required this.done, required this.release});

  /// The `SSHClient` (typed loosely so tests can pass anything to their starter).
  final Object client;
  final Future<void> done;
  final void Function() release;
}

/// Gets what [rule] needs to run: an SSH connection, or a ready ZeroTier network.
typedef ForwardConnect = Future<ForwardLease> Function(ForwardRule rule);
typedef ForwardStart = Future<RunningForward> Function(ForwardLease lease, ForwardRule rule, void Function() onChange);

class ForwardStatus {
  ForwardState state = ForwardState.stopped;
  Object? error;
  RunningForward? running;
  int attempt = 0;

  ForwardStats? get stats => running?.stats;

  bool get on => state == ForwardState.starting || state == ForwardState.active || state == ForwardState.reconnecting;
}

/// Texts for the background notification (translated by the app).
class ForwardingTexts {
  const ForwardingTexts({required this.title, required this.text, required this.stop});

  final String Function(int active) title;
  final String Function(int bytesIn, int bytesOut) text;
  final String stop;
}

/// Runs forwarding rules on pooled SSH connections, reconnects them when a connection drops, and keeps
/// the app alive (with a notification) while any runs.
class ForwardingManager extends ChangeNotifier {
  ForwardingManager({
    required this.connect,
    required this.startForward,
    required this.keepAlive,
    required this.log,
    required this.texts,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)],
  }) {
    _stopSub = keepAlive.stopRequested.listen((_) => stopAll());
  }

  final ForwardConnect connect;
  final ForwardStart startForward;
  final KeepAlive keepAlive;
  final Log log;
  ForwardingTexts Function() texts;

  /// Waits between reconnect attempts; after the last one the rule is marked failed.
  final List<Duration> retryDelays;

  final Map<String, ForwardStatus> _status = {};
  final Map<String, ForwardLease> _leases = {};
  final Map<String, ForwardRule> _rules = {};
  late final StreamSubscription<void> _stopSub;
  Timer? _ticker;
  bool _serviceOn = false;
  bool _disposed = false;

  ForwardStatus status(String ruleId) => _status.putIfAbsent(ruleId, ForwardStatus.new);

  int get activeCount => _status.values.where((s) => s.on).length;

  bool anyOn(String connectionId) => _rules.values.any((r) => r.connectionId == connectionId && status(r.id).on);

  int get bytesIn => _status.values.fold(0, (sum, s) => sum + (s.stats?.bytesIn ?? 0));
  int get bytesOut => _status.values.fold(0, (sum, s) => sum + (s.stats?.bytesOut ?? 0));

  Future<void> start(ForwardRule rule) async {
    final s = status(rule.id);
    if (s.on) return;
    _rules[rule.id] = rule;
    s
      ..state = ForwardState.starting
      ..error = null
      ..attempt = 0;
    _changed();
    await _run(rule);
  }

  Future<void> _run(ForwardRule rule) async {
    final s = status(rule.id);
    try {
      final lease = await connect(rule);
      if (!s.on) return lease.release();
      _leases[rule.id] = lease;
      s.running = await startForward(lease, rule, _throttled);
      if (!s.on) {
        await _teardown(rule.id);
        return;
      }
      s
        ..state = ForwardState.active
        ..attempt = 0;
      log.i('forwarding', 'Started ${rule.describe()}');
      _changed();
      unawaited(lease.done.whenComplete(() => _dropped(rule, lease)));
    } catch (e) {
      await _teardown(rule.id);
      // Configuration problems will not fix themselves; connection problems might.
      final retryable = e is! ForwardException;
      _fail(rule, e, retry: retryable);
    }
  }

  void _dropped(ForwardRule rule, ForwardLease lease) {
    final s = status(rule.id);
    // Only the lease in use counts (an old one finishing after a restart is not a drop).
    if (s.state != ForwardState.active || !identical(_leases[rule.id], lease)) return;
    log.w('forwarding', 'Connection lost for ${rule.describe()}');
    _teardown(rule.id);
    _fail(rule, const ForwardException(ForwardError.other, 'Connection lost'), retry: true);
  }

  void _fail(ForwardRule rule, Object error, {required bool retry}) {
    final s = status(rule.id);
    if (!s.on) return;
    s.error = error;
    if (retry && s.attempt < retryDelays.length) {
      final delay = retryDelays[s.attempt++];
      s.state = ForwardState.reconnecting;
      _changed();
      Timer(delay, () {
        if (s.state == ForwardState.reconnecting) _run(rule);
      });
    } else {
      log.w('forwarding', 'Failed ${rule.describe()}: $error');
      s.state = ForwardState.failed;
      _changed();
    }
  }

  Future<void> stop(String ruleId) async {
    final s = status(ruleId);
    s
      ..state = ForwardState.stopped
      ..error = null;
    await _teardown(ruleId);
    _changed();
  }

  Future<void> stopAll() async {
    for (final id in _status.keys.toList()) {
      if (status(id).on || status(id).state == ForwardState.failed) await stop(id);
    }
  }

  /// Stops and restarts a running rule with its new settings.
  Future<void> restartIfOn(ForwardRule rule) async {
    if (!status(rule.id).on) return;
    await stop(rule.id);
    await start(rule);
  }

  /// Starts the rules marked "start with nux".
  Future<void> startAuto(Iterable<ForwardRule> rules) async {
    for (final r in rules.where((r) => r.autoStart)) {
      unawaited(start(r));
    }
  }

  Future<void> _teardown(String ruleId) async {
    final s = status(ruleId);
    final running = s.running;
    s.running = null;
    try {
      await running?.close();
    } catch (_) {}
    _leases.remove(ruleId)?.release();
  }

  Timer? _throttle;
  void _throttled() {
    _throttle ??= Timer(const Duration(milliseconds: 300), () {
      _throttle = null;
      _notify();
    });
  }

  void _changed() {
    _notify();
    _syncService();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Starts, updates or stops the background service to match what runs.
  void _syncService() {
    final active = activeCount;
    final t = texts();
    if (active > 0 && !_serviceOn) {
      _serviceOn = true;
      unawaited(keepAlive.start(title: t.title(active), text: t.text(bytesIn, bytesOut), stopLabel: t.stop));
      _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
        final t = texts();
        keepAlive.update(title: t.title(activeCount), text: t.text(bytesIn, bytesOut));
      });
    } else if (active == 0 && _serviceOn) {
      _serviceOn = false;
      _ticker?.cancel();
      unawaited(keepAlive.stop());
    } else if (_serviceOn) {
      unawaited(keepAlive.update(title: t.title(active), text: t.text(bytesIn, bytesOut)));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSub.cancel();
    _ticker?.cancel();
    _throttle?.cancel();
    for (final id in _status.keys.toList()) {
      final running = _status[id]!.running;
      running?.close();
      _leases.remove(id)?.release();
    }
    if (_serviceOn) keepAlive.stop();
    super.dispose();
  }
}
