import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/files/domain/file_browser.dart';
import 'package:nux/features/files/domain/file_listing.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux_backend/nux_backend.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('nux-browser-');
    for (final n in ['b.txt', 'a10.txt', 'a2.txt', '.hidden']) {
      File('${dir.path}/$n').writeAsStringSync(n);
    }
    Directory('${dir.path}/zdir').createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  FileBrowser browser({String? path}) {
    var released = 0;
    return FileBrowser(
      path: path,
      open: () async => FsHandle(LocalFileSystem(dir.path), release: () => released++),
    );
  }

  test('starts at home, sorts folders first and naturally, hides dot files', () async {
    final b = browser();
    addTearDown(b.dispose);
    await b.start();
    expect(b.path, dir.path);
    expect(b.entries.map((e) => e.name), ['zdir', 'a2.txt', 'a10.txt', 'b.txt']);
    expect(b.hiddenCount, 1);
    b.toggleHidden();
    expect(b.entries.map((e) => e.name), contains('.hidden'));
    b.setSort(FileSort.name);
    expect(b.entries.map((e) => e.name), ['zdir', 'b.txt', 'a10.txt', 'a2.txt', '.hidden'],
        reason: 'same sort again flips the order; folders stay first');
  });

  test('navigates, creates, renames, moves, deletes', () async {
    final b = browser();
    addTearDown(b.dispose);
    await b.start();
    await b.mkdir('new');
    await b.rename(b.entries.firstWhere((e) => e.name == 'b.txt'), 'c.txt');
    await b.move(['${dir.path}/c.txt'], '${dir.path}/new');
    await b.cd('${dir.path}/new');
    expect(b.entries.map((e) => e.name), ['c.txt']);
    await b.up();
    expect(b.path, dir.path);
    b.toggleSelected(b.entries.firstWhere((e) => e.name == 'new'));
    expect(b.selecting, isTrue);
    await b.delete(b.selection.toList());
    expect(b.selecting, isFalse);
    expect(b.names, isNot(contains('new')));
  });

  test('errors are kept for the view', () async {
    final b = browser(path: '${dir.path}/missing');
    addTearDown(b.dispose);
    await b.start();
    expect(b.error, isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.notFound));
  });

  test('listing helpers', () {
    expect(permissionString(0x1ed), 'rwxr-xr-x');
    expect(permissionString(0x180), 'rw-------');
    expect(parseOctalMode('644'), 0x1a4);
    expect(parseOctalMode('9'), isNull);
    expect(formatSize(1023), '1023 B');
    expect(formatSize(1536), '1.5 KB');
    expect(formatSize(300 * 1024 * 1024), '300 MB');
    expect(fileKindByName('photo.JPG'), FileKind.image);
    expect(fileKindByName('README.md'), FileKind.markdown);
    expect(fileKindByName('main.dart'), FileKind.text);
    expect(looksBinary([0x7f, 0x45, 0x4c, 0x46, 0]), isTrue);
    expect(looksBinary('hello\n'.codeUnits), isFalse);
    expect(compareNatural('file2', 'file10'), lessThan(0));
  });
}
