import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where an entry comes from (its icon, and what it opens).
enum ActivitySource { git, transfer, forwarding, update, ssh, other }

enum ActivityState { running, done, failed, cancelled, info }

/// An operation (running, then done or failed) or an event, shown in the Activity sheet.
class ActivityEntry {
  ActivityEntry._(this.source, this.title, {this.subtitle, this.cancel, this.retry, this.open, required this.state})
    : started = clock.now();

  final ActivitySource source;
  String title;

  /// The latest line of progress, or how it ended (an error).
  String? subtitle;
  ActivityState state;

  /// 0–1 while running, when known.
  double? progress;
  final DateTime started;
  DateTime? ended;

  /// Set for operations that can be stopped / run again.
  VoidCallback? cancel;
  VoidCallback? retry;

  /// Shows its details (a git command's output, the transfers).
  final void Function(BuildContext context)? open;

  bool get running => state == ActivityState.running;
}

/// Everything nux is doing or did lately, from every part of the app: git commands, transfers, port
/// forwardings, updates, connections, and the results snackbars showed. Kept while the app runs.
class ActivityCenter extends ChangeNotifier {
  ActivityCenter({this.keep = 200});

  final int keep;
  final List<ActivityEntry> _entries = [];
  int _unread = 0;

  /// Newest first.
  List<ActivityEntry> get entries => _entries.reversed.toList();

  List<ActivityEntry> get running => entries.where((e) => e.running).toList();

  /// Finished operations and events not seen in the sheet yet.
  int get unread => _unread;

  ActivityEntry _add(ActivityEntry e) {
    _entries.add(e);
    if (_entries.length > keep) {
      final i = _entries.indexWhere((x) => !x.running);
      _entries.removeAt(i < 0 ? 0 : i);
    }
    notifyListeners();
    return e;
  }

  /// Starts an operation; [finish] it later.
  ActivityEntry start(
    ActivitySource source,
    String title, {
    String? subtitle,
    VoidCallback? cancel,
    VoidCallback? retry,
    void Function(BuildContext context)? open,
  }) => _add(
    ActivityEntry._(
      source,
      title,
      subtitle: subtitle,
      cancel: cancel,
      retry: retry,
      open: open,
      state: ActivityState.running,
    ),
  );

  void update(ActivityEntry e, {double? progress, String? subtitle, String? title}) {
    if (!e.running) return;
    e
      ..progress = progress ?? e.progress
      ..subtitle = subtitle ?? e.subtitle
      ..title = title ?? e.title;
    notifyListeners();
  }

  void finish(ActivityEntry e, ActivityState state, {String? subtitle, bool unread = true}) {
    if (!e.running) return;
    e
      ..state = state
      ..progress = null
      ..ended = clock.now()
      ..subtitle = subtitle ?? e.subtitle
      ..cancel = null;
    if (unread && state != ActivityState.cancelled) _unread++;
    notifyListeners();
  }

  /// Something that happened. [unread] marks it new (a dot on the tab count) until the sheet is opened.
  ActivityEntry event(
    ActivitySource source,
    String title, {
    String? subtitle,
    ActivityState state = ActivityState.info,
    VoidCallback? retry,
    void Function(BuildContext context)? open,
    bool unread = true,
  }) {
    final e = ActivityEntry._(source, title, subtitle: subtitle, retry: retry, open: open, state: state)
      ..ended = clock.now();
    if (unread) _unread++;
    return _add(e);
  }

  void markRead() {
    if (_unread == 0) return;
    _unread = 0;
    notifyListeners();
  }

  /// Forgets everything that is not running.
  void clear() {
    _entries.removeWhere((e) => !e.running);
    _unread = 0;
    notifyListeners();
  }
}

final activityCenterProvider = Provider<ActivityCenter>((ref) {
  final center = ActivityCenter();
  ref.onDispose(center.dispose);
  return center;
});
