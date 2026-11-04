import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log_file.dart';
import 'redact.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;

  /// Area of the app, e.g. `ssh`, `forwarding`, `updates`.
  final String tag;
  final String message;

  @override
  String toString() => '${time.toIso8601String()} ${level.name.toUpperCase()} [$tag] $message';
}

/// The app log (newest last), kept in memory and, once [persistTo] is called, in a file that survives
/// restarts and crashes. Shareable with hosts masked.
///
/// Messages are redacted when they are written, so a secret never even reaches memory (or disk) here.
class Log extends ChangeNotifier {
  Log({this.capacity = 2000});

  final int capacity;
  final _entries = ListQueue<LogEntry>();
  LogFile? _file;

  /// Starts writing to a file in [directory] (with what was logged so far), marking a new launch.
  void persistTo(String directory) {
    if (_file != null) return;
    final file = LogFile(directory);
    file.write('--- ${clock.now().toIso8601String()} nux started ---');
    for (final e in _entries) {
      file.write('$e');
    }
    _file = file;
  }

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void d(String tag, String message) => add(LogLevel.debug, tag, message);
  void i(String tag, String message) => add(LogLevel.info, tag, message);
  void w(String tag, String message) => add(LogLevel.warning, tag, message);

  void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      add(LogLevel.error, tag, [message, ?error?.toString(), if (stack != null) '$stack'].join('\n'));

  void add(LogLevel level, String tag, String message) {
    final entry = LogEntry(clock.now(), level, tag, redact(message));
    _entries.addLast(entry);
    _file?.write('$entry');
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    if (kDebugMode) debugPrint(entry.toString());
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _file?.clear();
    notifyListeners();
  }

  /// The log as text for sharing (from earlier launches too, once persisted); hosts and addresses are
  /// masked unless [includeHosts].
  String export({bool includeHosts = false}) {
    final text = _file?.read().trimRight() ?? _entries.join('\n');
    return includeHosts ? text : redact(text, maskHosts: true);
  }

  @override
  void dispose() {
    _file?.close();
    super.dispose();
  }
}

/// The app log. Widgets that show it listen to the [Log] itself (it is a [ChangeNotifier]).
final logProvider = Provider<Log>((ref) {
  final log = Log();
  ref.onDispose(log.dispose);
  return log;
});
