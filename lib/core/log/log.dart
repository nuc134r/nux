import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// In-memory app log (newest last), shown in a logs screen and shareable.
///
/// Messages are redacted when they are written, so a secret never even reaches memory here.
class Log extends ChangeNotifier {
  Log({this.capacity = 2000});

  final int capacity;
  final _entries = ListQueue<LogEntry>();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void d(String tag, String message) => add(LogLevel.debug, tag, message);
  void i(String tag, String message) => add(LogLevel.info, tag, message);
  void w(String tag, String message) => add(LogLevel.warning, tag, message);

  void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      add(LogLevel.error, tag, [message, ?error?.toString(), if (stack != null) '$stack'].join('\n'));

  void add(LogLevel level, String tag, String message) {
    final entry = LogEntry(clock.now(), level, tag, redact(message));
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    if (kDebugMode) debugPrint(entry.toString());
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// The log as text for sharing; hosts and addresses are masked unless [includeHosts].
  String export({bool includeHosts = false}) =>
      _entries.map((e) => includeHosts ? '$e' : redact('$e', maskHosts: true)).join('\n');
}

/// The app log. Widgets that show it listen to the [Log] itself (it is a [ChangeNotifier]).
final logProvider = Provider<Log>((ref) {
  final log = Log();
  ref.onDispose(log.dispose);
  return log;
});
