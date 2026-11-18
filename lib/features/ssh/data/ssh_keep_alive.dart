import 'dart:async';

import '../../../core/background/keep_alive.dart';
import 'ssh_pool.dart';

/// Keeps the app running in the background while SSH connections are in use (terminals, file browsers),
/// like Termux: Android would otherwise freeze the process and the server would drop the sessions.
class SshKeepAlive {
  SshKeepAlive(this._pool, this._keepAlive, {required this.title, required this.stopLabel, String? Function(String id)? name})
    : name = name ?? ((_) => null) {
    _pool.addListener(_sync);
    _stopSub = _keepAlive.stopRequested.listen((_) => _pool.disconnectAll());
    _sync();
  }

  final SshPool _pool;
  final KeepAlive _keepAlive;
  final String Function(int connections) title;
  final String Function() stopLabel;

  /// A connection's name for the notification (one per line); null leaves it out.
  final String? Function(String id) name;
  late final StreamSubscription<void> _stopSub;
  int _shown = 0;
  String _text = '';

  void _sync() {
    final ids = _pool.inUse;
    final n = ids.length;
    final text = [for (final id in ids) ?name(id)].join('\n');
    if (n == _shown && text == _text) return;
    if (n == 0) {
      unawaited(_keepAlive.stop());
    } else if (_shown == 0) {
      unawaited(_keepAlive.start(title: title(n), text: text, stopLabel: stopLabel()));
    } else {
      unawaited(_keepAlive.update(title: title(n), text: text));
    }
    _shown = n;
    _text = text;
  }

  void dispose() {
    _pool.removeListener(_sync);
    _stopSub.cancel();
    if (_shown > 0) unawaited(_keepAlive.stop());
  }
}
