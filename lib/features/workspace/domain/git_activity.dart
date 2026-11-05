import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// One git command run from nux: what it printed, and how it ended.
class GitRun {
  GitRun(this.command, {this.cancel}) : started = clock.now();

  /// As one would type it (`git pull --rebase`), without credentials.
  final String command;
  final DateTime started;
  DateTime? ended;
  int? exitCode;
  bool cancelled = false;

  /// Stops the command; null when it cannot be stopped.
  final VoidCallback? cancel;

  /// Output lines, a progress line (ending in `\r`) replaced by the next one as a terminal would.
  final List<String> lines = [];
  bool _overwrite = false;

  bool get running => ended == null;
  bool get ok => exitCode == 0;

  /// The latest line with something in it ("Receiving objects: 45% (9/20)").
  String get lastLine => lines.lastWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();

  /// 0–1 from the latest "NN%", while running.
  double? get progress {
    if (!running) return null;
    final m = RegExp(r'(\d{1,3})%').allMatches(lastLine).lastOrNull;
    return m == null ? null : (int.parse(m.group(1)!) / 100).clamp(0, 1).toDouble();
  }

  Duration get duration => (ended ?? clock.now()).difference(started);

  String get output => lines.join('\n');

  void _add(String chunk) {
    for (final (i, part) in chunk.split('\n').indexed) {
      if (i > 0) {
        lines.add('');
        _overwrite = false;
      }
      // `\r`: the line starts again (git's progress counters).
      final pieces = part.split('\r');
      for (final (j, piece) in pieces.indexed) {
        if (j > 0) _overwrite = true;
        if (piece.isEmpty && j > 0) continue;
        if (lines.isEmpty) lines.add('');
        if (_overwrite) {
          lines[lines.length - 1] = piece;
          _overwrite = false;
        } else {
          lines[lines.length - 1] += piece;
        }
      }
      if (part.endsWith('\r')) _overwrite = true;
    }
    if (lines.length > 2000) lines.removeRange(0, lines.length - 2000);
  }
}

/// The git commands run in a workspace from nux, newest last: the one running now shows its progress,
/// and earlier ones keep their output to look at.
class GitActivity extends ChangeNotifier {
  GitActivity({this.keep = 30});

  final int keep;
  final List<GitRun> _runs = [];

  List<GitRun> get runs => List.unmodifiable(_runs);

  GitRun? get current => _runs.where((r) => r.running).lastOrNull;

  GitRun? get last => _runs.lastOrNull;

  GitRun start(String command, {VoidCallback? cancel}) {
    final run = GitRun(command, cancel: cancel);
    _runs.add(run);
    if (_runs.length > keep) _runs.removeAt(0);
    notifyListeners();
    return run;
  }

  void output(GitRun run, String chunk) {
    run._add(chunk);
    notifyListeners();
  }

  void finish(GitRun run, int? exitCode) {
    run
      ..exitCode = exitCode
      ..ended = clock.now();
    notifyListeners();
  }

  void cancel(GitRun run) {
    if (!run.running || run.cancel == null) return;
    run.cancelled = true;
    run.cancel!();
    notifyListeners();
  }
}
