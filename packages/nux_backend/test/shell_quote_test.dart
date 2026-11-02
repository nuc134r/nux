import 'package:nux_backend/nux_backend.dart';
import 'package:test/test.dart';

void main() {
  group('shellQuote', () {
    test('leaves plain words alone', () {
      expect(shellQuote('main.dart'), 'main.dart');
      expect(shellQuote('/usr/local/bin'), '/usr/local/bin');
      expect(shellQuote('--format=%H'), '--format=%H');
    });

    test('quotes empty strings, spaces and metacharacters', () {
      expect(shellQuote(''), "''");
      expect(shellQuote('my file.txt'), "'my file.txt'");
      expect(shellQuote(r'$HOME'), r"'$HOME'");
      expect(shellQuote('a;rm -rf /'), "'a;rm -rf /'");
      expect(shellQuote('*'), "'*'");
    });

    test('escapes single quotes', () {
      expect(shellQuote("it's"), "'it'\"'\"'s'");
    });

    test('joins words', () {
      expect(shellJoin(['git', 'commit', '-m', 'Fix: the "thing"']), "git commit -m 'Fix: the \"thing\"'");
    });
  });

  group('FileEntry', () {
    test('name and hidden', () {
      const e = FileEntry(path: '/home/user/.bashrc', type: FileType.file);
      expect(e.name, '.bashrc');
      expect(e.isHidden, isTrue);
      expect(const FileEntry(path: '/', type: FileType.directory).name, '');
      expect(const FileEntry(path: '/srv/app/', type: FileType.directory).name, 'app');
    });
  });
}
