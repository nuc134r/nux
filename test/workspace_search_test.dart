import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/workspace/domain/workspace_search.dart';
import 'package:nux_backend/nux_backend.dart';

Future<CommandResult> sh(String command) async {
  final r = await Process.run('sh', ['-c', command]);
  return CommandResult(exitCode: r.exitCode, stdout: r.stdout as String, stderr: r.stderr as String);
}

void main() {
  test('fuzzy: file names first, then word starts and runs', () {
    final paths = ['lib/main.dart', 'lib/features/maintenance/a.dart', 'test/main_test.dart', 'docs/MANUAL.md', 'README.md'];
    expect(fuzzyFilter('main', paths).first, 'lib/main.dart');
    expect(fuzzyFilter('mt', paths).first, 'test/main_test.dart');
    expect(fuzzyFilter('xyz', paths), isEmpty);
    expect(fuzzyFilter('', paths), hasLength(paths.length));
    expect(fuzzyScore('fma', 'lib/features/maintenance/a.dart'), isNotNull, reason: 'across folders');
  });

  test('parses search output, including paths with colons', () {
    final hits = parseSearch(const CommandResult(
      exitCode: 0,
      stdout: './lib/a.dart\x0012:  final x = 1;\nweird:name.txt\x003:x marks\n',
      stderr: '',
    ));
    expect([for (final h in hits) '${h.path}@${h.line}:${h.text}'], ['lib/a.dart@12:  final x = 1;', 'weird:name.txt@3:x marks']);
  });

  test('the commands work in a real folder (grep or rg, git or find)', () async {
    final root = Directory.systemTemp.createTempSync('nux-search-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/lib').createSync();
    File('${root.path}/lib/a.dart').writeAsStringSync('one\nHello there\n');
    File('${root.path}/b.txt').writeAsStringSync('hello again\n');
    expect(parseFileList(await sh(listFilesCommand(root.path)))..sort(), ['b.txt', 'lib/a.dart']);
    final hits = parseSearch(await sh(searchCommand(root.path, 'hello')));
    expect({for (final h in hits) '${h.path}:${h.line}'}, {'lib/a.dart:2', 'b.txt:1'});
    expect(parseSearch(await sh(searchCommand(root.path, 'Hello'))).single.path, 'lib/a.dart', reason: 'smart case');
  });
}
