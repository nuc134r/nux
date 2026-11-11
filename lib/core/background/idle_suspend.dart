import 'dart:async';

import 'package:flutter/widgets.dart';

import 'keep_alive_hub.dart';

/// Runs [suspend] once nux has been out of sight for [after] with no [KeepAliveHub] slot held (no SSH
/// connection in use, no forward), and [resume] when it is shown again.
///
/// Pressing Home leaves the app alive (only Back or a swipe detaches it, see BackgroundQuit): what
/// idles then, the ZeroTier node above all, keeps using CPU until Android kills nux for it.
class IdleSuspend {
  IdleSuspend({
    required this.hub,
    required this.suspend,
    required this.resume,
    this.after = const Duration(minutes: 2),
  }) {
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
    _hubSub = hub.changes.listen((_) => _check());
  }

  final KeepAliveHub hub;
  final Future<void> Function() suspend;
  /// Called whenever nux is shown again; a no-op unless [suspend] ran.
  final Future<void> Function() resume;
  final Duration after;

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _hubSub;
  bool _away = false;
  Timer? _timer;

  void _onState(AppLifecycleState state) {
    final away = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    // Shown again (through inactive, so not only right after paused); resume does nothing unless suspended.
    if (state == AppLifecycleState.resumed) unawaited(resume());
    _away = away;
    _check();
  }

  void _check() {
    if (!_away || hub.active.isNotEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(after, () {
      _timer = null;
      if (_away && hub.active.isEmpty) unawaited(suspend());
    });
  }

  void dispose() {
    _timer?.cancel();
    _hubSub.cancel();
    _lifecycle.dispose();
  }
}
