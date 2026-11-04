import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:nux_backend/nux_backend.dart';

/// Runs commands on this machine with `sh -c` (git and searches in tests).
class LocalRunner implements ProcessRunner {
  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async {
    final r = await Process.run('sh', ['-c', command], workingDirectory: workingDirectory, environment: environment);
    return CommandResult(exitCode: r.exitCode, stdout: r.stdout as String, stderr: r.stderr as String);
  }

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) async =>
      _Local(await Process.start('sh', ['-c', command], workingDirectory: workingDirectory, environment: environment));
}

class _Local implements RunningProcess {
  _Local(this._p);

  final Process _p;

  @override
  StreamSink<List<int>> get stdin => _p.stdin;

  @override
  Stream<Uint8List> get stdout => _p.stdout.map(Uint8List.fromList);

  @override
  Stream<Uint8List> get stderr => _p.stderr.map(Uint8List.fromList);

  @override
  Future<int?> get exitCode => _p.exitCode;

  @override
  void kill() => _p.kill();
}
