import 'dart:async';
import 'dart:typed_data';

/// Result of a finished command.
class CommandResult {
  const CommandResult({required this.exitCode, required this.stdout, required this.stderr});

  /// Null when the backend did not report one (e.g. the process was killed by a signal).
  final int? exitCode;
  final String stdout;
  final String stderr;

  bool get ok => exitCode == 0;

  @override
  String toString() => 'CommandResult(exit $exitCode, ${stdout.length} chars out, ${stderr.length} chars err)';
}

/// A running non-interactive process (an SSH exec channel, a local Process).
abstract interface class RunningProcess {
  StreamSink<List<int>> get stdin;
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;

  /// Completes when the process ends; null when no exit code was reported.
  Future<int?> get exitCode;

  void kill();
}

/// Runs commands on a backend. Commands are shell strings: quote arguments with [shellQuote].
abstract interface class ProcessRunner {
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment});

  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment});
}
