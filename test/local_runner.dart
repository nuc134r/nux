import 'dart:io';

import 'package:nux_backend/nux_backend.dart';

/// Runs commands on this machine with `sh -c` (git and searches in tests).
class LocalRunner implements ProcessRunner {
  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async {
    final r = await Process.run('sh', ['-c', command], workingDirectory: workingDirectory, environment: environment);
    return CommandResult(exitCode: r.exitCode, stdout: r.stdout as String, stderr: r.stderr as String);
  }

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) =>
      throw UnimplementedError();
}
