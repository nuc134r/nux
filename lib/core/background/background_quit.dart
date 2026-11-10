import 'dart:async';

import 'package:flutter/widgets.dart';

import 'keep_alive_hub.dart';

/// Quits nux once it has no screen and nothing to keep running.
///
/// The Flutter engine outlives the screen (android/.../NuxEngine.kt) so that terminals and forwards keep
/// going after Back or a swipe from the recent apps. Without them it only idled: the ZeroTier node, timers
/// and the log carried on until Android killed the process, maybe hours later. Now, when the screen is
/// gone (the app is detached) and no [KeepAliveHub] slot is held (no SSH connection in use, no forward),
/// [shutdown] runs and the process ends: after Back from Home, or after the notification's Stop with the
/// app closed. A grace period lets a recreated screen come back first.
class BackgroundQuit {
  BackgroundQuit({
    required this.hub,
    required this.shutdown,
    required this.quit,
    this.grace = const Duration(seconds: 3),
  }) {
    _lifecycle = AppLifecycleListener(onStateChange: _onState);
    _hubSub = hub.changes.listen((_) => _check());
  }

  final KeepAliveHub hub;

  /// Stops what runs without a slot (the ZeroTier node, idle connections) and says so in the log.
  final Future<void> Function() shutdown;

  /// Ends the process.
  final void Function() quit;
  final Duration grace;

  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _hubSub;
  bool _detached = false;
  Timer? _timer;
  bool _quitting = false;

  void _onState(AppLifecycleState state) {
    _detached = state == AppLifecycleState.detached;
    _check();
  }

  void _check() {
    if (!_detached || hub.active.isNotEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(grace, () async {
      _timer = null;
      if (_quitting || !_detached || hub.active.isNotEmpty) return;
      _quitting = true;
      try {
        await shutdown();
      } finally {
        quit();
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _hubSub.cancel();
    _lifecycle.dispose();
  }
}
