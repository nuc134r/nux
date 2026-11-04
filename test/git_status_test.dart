import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/workspace/domain/git_status.dart';
import 'package:nux_backend/nux_backend.dart';

void main() {
  test('reads branch, ahead/behind and changes with absolute paths', () {
    final out = '/home/dev/app\n'
        '## main...origin/main [ahead 2, behind 1]\x00'
        ' M lib/a.dart\x00'
        'M  lib/b.dart\x00'
        'A  lib/new.dart\x00'
        '?? notes.md\x00'
        'R  lib/to.dart\x00lib/from.dart\x00'
        ' D old.txt\x00'
        'UU lib/merge.dart\x00';
    final s = parseGitStatus(CommandResult(exitCode: 0, stdout: out, stderr: ''))!;
    expect((s.root, s.branch, s.ahead, s.behind), ('/home/dev/app', 'main', 2, 1));
    expect([for (final c in s.changes) '${c.kind.letter} ${c.path} ${c.staged}'], [
      'M /home/dev/app/lib/a.dart false',
      'M /home/dev/app/lib/b.dart true',
      'A /home/dev/app/lib/new.dart true',
      'U /home/dev/app/notes.md false',
      'R /home/dev/app/lib/to.dart true',
      'D /home/dev/app/old.txt false',
      '! /home/dev/app/lib/merge.dart false',
    ]);
    expect(s.changedFolders, {'/home/dev/app/lib', '/home/dev/app', '/home/dev', '/home'});
  });

  test('no branch yet, detached HEAD, not a repository', () {
    GitStatus? parse(String out, [int code = 0]) => parseGitStatus(CommandResult(exitCode: code, stdout: out, stderr: ''));
    expect(parse('/r\n## No commits yet on main\x00')!.branch, 'main');
    expect(parse('/r\n## HEAD (no branch)\x00')!.branch, isNull);
    expect(parse('', 128), isNull);
  });
}
