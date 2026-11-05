/// Writing a file the login user may not write, through sudo. The password goes to sudo through stdin
/// (`sudo -S`), never on a command line or into a file.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nux_backend/nux_backend.dart';

class SudoException implements Exception {
  const SudoException(this.message, {this.wrongPassword = false, this.notAllowed = false});

  final String message;

  /// sudo refused the password.
  final bool wrongPassword;

  /// sudo is missing or this user may not use it.
  final bool notAllowed;

  @override
  String toString() => message;
}

/// Runs [command] with [input] on stdin; returns the exit code and stderr.
Future<(int?, String)> _run(ProcessRunner runner, String command, List<int> input) async {
  final p = await runner.start(command);
  final err = StringBuffer();
  final errDone = p.stderr.cast<List<int>>().transform(utf8.decoder).listen(err.write).asFuture<void>();
  final outDone = p.stdout.drain<void>();
  p.stdin.add(input);
  await p.stdin.close();
  final code = await p.exitCode;
  await Future.wait([errDone, outDone]);
  return (code, '$err'.trim());
}

/// Whether sudo needs a password here (false when it is allowed without one, or remembers it).
Future<bool> sudoNeedsPassword(ProcessRunner runner) async => !(await runner.run('sudo -n true')).ok;

/// Checks [password] (sudo asks for it again: `-k`).
Future<void> sudoCheck(ProcessRunner runner, String password) async {
  final (code, err) = await _run(runner, "sudo -S -k -p '' true", utf8.encode('$password\n'));
  if (code == 0) return;
  throw _error(err);
}

/// Writes [data] to [path] as root, keeping the file's owner and mode (it is overwritten in place).
/// With a [password], sudo is made to ask (`-k`) and reads it from the first line of stdin; the rest is
/// the file.
Future<void> sudoWrite(ProcessRunner runner, String path, Uint8List data, {String? password}) async {
  final write = "sh -c 'cat > \"\$1\"' sh ${shellQuote(path)}";
  final (code, err) = password == null
      ? await _run(runner, 'sudo -n $write', data)
      : await _run(runner, "sudo -S -k -p '' $write", [...utf8.encode('$password\n'), ...data]);
  if (code == 0) return;
  throw _error(err);
}

SudoException _error(String err) {
  final e = err.toLowerCase();
  return SudoException(
    err.isEmpty ? 'sudo failed' : err,
    wrongPassword: e.contains('incorrect password') || e.contains('sorry, try again') || e.contains('authentication'),
    notAllowed: e.contains('not in the sudoers') || e.contains('not allowed') || e.contains('command not found'),
  );
}
