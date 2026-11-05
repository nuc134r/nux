import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/viewer/domain/sudo_write.dart';
import 'package:nux_backend/nux_backend.dart';

import 'local_runner.dart';

/// Runs commands with a fake `sudo` first on PATH: it wants the password "secret" (read from stdin with
/// -S, a byte at a time like the real one) unless NOPASSWD is set, and logs each password it reads.
class FakeSudoRunner implements ProcessRunner {
  FakeSudoRunner(this.bin);

  final String bin;
  final _local = LocalRunner();

  String _wrap(String command) => 'PATH=${shellQuote(bin)}:\$PATH; $command';

  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) =>
      _local.run(_wrap(command), workingDirectory: workingDirectory, environment: environment);

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) =>
      _local.start(_wrap(command), workingDirectory: workingDirectory, environment: environment);
}

const _fakeSudo = r'''#!/bin/sh
nopass=$(cat "$(dirname "$0")/nopasswd" 2>/dev/null)
stdin_pw=0; n=0
while [ $# -gt 0 ]; do
  case "$1" in
    -S) stdin_pw=1; shift;;
    -n) n=1; shift;;
    -k) shift;;
    -p) shift 2;;
    *) break;;
  esac
done
if [ "$nopass" != "yes" ]; then
  if [ $n = 1 ]; then echo "sudo: a password is required" >&2; exit 1; fi
  pw=""
  while :; do
    c=$(dd bs=1 count=1 2>/dev/null)
    [ -z "$c" ] && break
    pw="$pw$c"
  done
  echo "$pw" >> "$(dirname "$0")/passwords"
  if [ "$pw" != "secret" ]; then echo "Sorry, try again." >&2; echo "sudo: 1 incorrect password attempt" >&2; exit 1; fi
fi
exec "$@"
''';

void main() {
  late Directory dir;
  late FakeSudoRunner runner;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nux-sudo-');
    final bin = Directory('${dir.path}/bin')..createSync();
    File('${bin.path}/sudo').writeAsStringSync(_fakeSudo);
    Process.runSync('chmod', ['+x', '${bin.path}/sudo']);
    runner = FakeSudoRunner(bin.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('with a password: checked, then the file is written after it, never on a command line', () async {
    final target = File('${dir.path}/etc.conf')..writeAsStringSync('old\n');
    expect(await sudoNeedsPassword(runner), isTrue);
    await expectLater(
      sudoCheck(runner, 'wrong'),
      throwsA(isA<SudoException>().having((e) => e.wrongPassword, 'wrongPassword', isTrue)),
    );
    await sudoCheck(runner, 'secret');
    await sudoWrite(runner, target.path, Uint8List.fromList(utf8.encode('new\nline 2\n')), password: 'secret');
    expect(target.readAsStringSync(), 'new\nline 2\n');
  });

  test('without a password when sudo allows it', () async {
    File('${dir.path}/bin/nopasswd').writeAsStringSync('yes');
    final target = File('${dir.path}/it s.conf');
    expect(await sudoNeedsPassword(runner), isFalse);
    await sudoWrite(runner, target.path, Uint8List.fromList(utf8.encode('x')));
    expect(target.readAsStringSync(), 'x');
  });
}
