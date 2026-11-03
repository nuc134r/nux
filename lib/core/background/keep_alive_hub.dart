import 'dart:async';

import 'keep_alive.dart';

/// One foreground service, several reasons to keep running (SSH sessions, port forwards): each holds a
/// [slot], and the notification shows them together. The notification's button stops all of them.
class KeepAliveHub {
  KeepAliveHub(this._service, {required this.stopLabel, required this.idleText});

  final KeepAlive _service;

  /// Button label when several slots are active ("Disconnect all").
  final String Function() stopLabel;

  /// Notification text when no slot has one.
  final String Function() idleText;

  final Map<String, _Entry> _active = {};
  final Map<String, int> _order = {};
  bool _on = false;
  String? _label;
  ({String title, String text})? _shown;
  Future<void> _queue = Future.value();

  /// A [KeepAlive] for one reason; slots with a lower [order] come first in the notification.
  KeepAlive slot(String id, {int order = 0}) {
    _order[id] = order;
    return _Slot(this, id);
  }

  /// Ids of the slots that keep the service running.
  Set<String> get active => _active.keys.toSet();

  void _set(String id, _Entry e) {
    _active[id] = e;
    _sync();
  }

  void _update(String id, String title, String text) {
    final e = _active[id];
    if (e == null) return;
    _active[id] = _Entry(title, text, e.stopLabel);
    _sync();
  }

  void _clear(String id) {
    if (_active.remove(id) != null) _sync();
  }

  void _sync() {
    if (_active.isEmpty) {
      if (!_on) return;
      _on = false;
      _label = null;
      _shown = null;
      _enqueue(_service.stop);
      return;
    }
    final entries = _active.entries.toList()..sort((a, b) => (_order[a.key] ?? 0).compareTo(_order[b.key] ?? 0));
    final title = entries.map((e) => e.value.title).where((t) => t.isNotEmpty).join(' · ');
    final texts = entries.map((e) => e.value.text).where((t) => t.isNotEmpty).join(' · ');
    final text = texts.isEmpty ? idleText() : texts;
    final label = entries.length == 1 ? entries.single.value.stopLabel : stopLabel();
    _shown = (title: title, text: text);
    if (!_on || label != _label) {
      _on = true;
      _label = label;
      _enqueue(() => _service.start(title: title, text: text, stopLabel: label));
    } else {
      _enqueue(() => _service.update(title: title, text: text));
    }
  }

  /// Starts the service again if it should run (call when the app comes back to the foreground: a start
  /// refused in the background, or a service the system stopped, is retried).
  void resync() {
    final shown = _shown, label = _label;
    if (!_on || shown == null || label == null) return;
    _enqueue(() => _service.start(title: shown.title, text: shown.text, stopLabel: label));
  }

  /// Service calls run in order (a quick start-stop must not end with the service running).
  void _enqueue(Future<void> Function() op) {
    _queue = _queue.then((_) => op()).catchError((Object _) {});
  }
}

class _Entry {
  const _Entry(this.title, this.text, this.stopLabel);

  final String title;
  final String text;
  final String stopLabel;
}

class _Slot implements KeepAlive {
  _Slot(this._hub, this._id);

  final KeepAliveHub _hub;
  final String _id;

  @override
  Future<void> start({required String title, required String text, required String stopLabel}) async =>
      _hub._set(_id, _Entry(title, text, stopLabel));

  @override
  Future<void> update({required String title, required String text}) async => _hub._update(_id, title, text);

  @override
  Future<void> stop() async => _hub._clear(_id);

  @override
  Stream<void> get stopRequested => _hub._service.stopRequested;
}
