import 'dart:async';

import '../../../core/background/keep_alive.dart';
import 'ssh_pool.dart';

/// Keeps the app running in the background while SSH connections are in use (terminals, file browsers),
/// like Termux: Android would otherwise freeze the process and the server would drop the sessions.
class SshKeepAlive {
  SshKeepAlive(this._pool, this._keepAlive, {required this.title, required this.stopLabel}) {
    _pool.addListener(_sync);
    _stopSub = _keepAlive.stopRequested.listen((_) => _pool.disconnectAll());
    _sync();
  }

  final SshPool _pool;
  final KeepAlive _keepAlive;
  final String Function(int connections) title;
  final String Function() stopLabel;
  late final StreamSubscription<void> _stopSub;
  int _shown = 0;

  void _sync() {
    final n = _pool.inUseCount;
    if (n == _shown) return;
    if (n == 0) {
      unawaited(_keepAlive.stop());
    } else if (_shown == 0) {
      unawaited(_keepAlive.start(title: title(n), text: '', stopLabel: stopLabel()));
    } else {
      unawaited(_keepAlive.update(title: title(n), text: ''));
    }
    _shown = n;
  }

  void dispose() {
    _pool.removeListener(_sync);
    _stopSub.cancel();
    if (_shown > 0) unawaited(_keepAlive.stop());
  }
}
