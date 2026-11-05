import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/terminal/domain/terminal_paths.dart';

void main() {
  test('paths, with a line from grep or a compiler', () {
    expect(parseTerminalPath('lib/main.dart'), (path: 'lib/main.dart', line: null));
    expect(parseTerminalPath('lib/main.dart:12:5'), (path: 'lib/main.dart', line: 12));
    expect(parseTerminalPath('src/app.py:40:'), (path: 'src/app.py', line: 40));
    expect(parseTerminalPath('/etc/nginx/nginx.conf'), (path: '/etc/nginx/nginx.conf', line: null));
    expect(parseTerminalPath('~/.bashrc'), (path: '~/.bashrc', line: null));
    expect(parseTerminalPath('./run.sh'), (path: './run.sh', line: null));
    expect(parseTerminalPath('notes.md.'), (path: 'notes.md', line: null));
    expect(parseTerminalPath('.env'), (path: '.env', line: null));
  });

  test('not paths', () {
    for (final t in ['hello', 'https://example.com/a.txt', '--file', '/', 'src/', '1.5', '', 'a b/c']) {
      expect(parseTerminalPath(t), isNull, reason: t);
    }
  });

  test('resolving against the shell folder and home', () {
    expect(resolveTerminalPath('/a/../b', cwd: null), '/b');
    expect(resolveTerminalPath('~/x', home: '/home/u'), '/home/u/x');
    expect(resolveTerminalPath('~/x'), isNull);
    expect(resolveTerminalPath('../y.txt', cwd: '/srv/app'), '/srv/y.txt');
    expect(resolveTerminalPath('y.txt'), isNull);
    expect(pwdPath('file://host.example.com/srv/my%20app'), '/srv/my app');
    expect(pwdPath('/srv'), '/srv');
    expect(pwdPath(''), isNull);
  });
}
