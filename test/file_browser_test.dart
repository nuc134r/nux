import 'dart:async';
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

  test('relative ages', () {
    final now = DateTime(2026, 11, 3, 15, 30);
    expect(ageOf(now.subtract(const Duration(seconds: 20)), now), (AgeUnit.justNow, 0));
    expect(ageOf(now.subtract(const Duration(minutes: 5)), now), (AgeUnit.minutes, 5));
    expect(ageOf(DateTime(2026, 11, 3, 9), now), (AgeUnit.hours, 6));
    expect(ageOf(DateTime(2026, 11, 2, 23), now), (AgeUnit.yesterday, 1), reason: 'before midnight is yesterday');
    expect(ageOf(DateTime(2026, 10, 30, 12), now), (AgeUnit.days, 4));
    expect(ageOf(DateTime(2026, 3, 5), now), (AgeUnit.sameYear, 0));
    expect(ageOf(DateTime(2024, 3, 5), now), (AgeUnit.olderYear, 0));
    expect(ageOf(DateTime(2026, 11, 4), now), (AgeUnit.sameYear, 0), reason: 'future (clock skew) shows the date');
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

  test('a request that never answers drops the connection and says so; the old listing stays', () async {
    var opened = 0, dropped = 0;
    final stalled = <String>{};
    final b = FileBrowser(
      timeout: const Duration(milliseconds: 200),
      open: () async {
        opened++;
        return FsHandle(_Stalling(LocalFileSystem(dir.path), stalled), release: () {}, drop: () => dropped++);
      },
    );
    addTearDown(b.dispose);
    await b.start();
    expect(b.entries, isNotEmpty);

    stalled.add('${dir.path}/zdir');
    await b.cd('${dir.path}/zdir');
    expect(b.loading, isFalse);
    expect(b.error, isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.disconnected));
    expect(dropped, 1);
    expect(b.path, dir.path, reason: 'still where it was');
    expect(b.entries, isNotEmpty, reason: 'the last listing stays visible');

    stalled.clear();
    await b.cd('${dir.path}/zdir');
    expect(b.error, isNull);
    expect(opened, 2, reason: 'the next request connects again');
  });

  test('a dropped connection is reported at once', () async {
    final drop = Completer<void>();
    final b = FileBrowser(open: () async => FsHandle(LocalFileSystem(dir.path), release: () {}, done: drop.future));
    addTearDown(b.dispose);
    await b.start();
    var notified = 0;
    b.addListener(() => notified++);
    drop.complete();
    await Future<void>.delayed(Duration.zero);
    expect(b.error, isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.disconnected));
    expect(notified, greaterThan(0));
  });

  test('only the latest navigation is shown', () async {
    final slow = <String>{'${dir.path}/zdir'};
    final b = FileBrowser(open: () async => FsHandle(_Stalling(LocalFileSystem(dir.path), slow, release: true), release: () {}));
    addTearDown(b.dispose);
    await b.start();
    final first = b.cd('${dir.path}/zdir'); // answers late
    await b.cd(dir.path);
    _Stalling.releaseAll();
    await first;
    expect(b.path, dir.path);
  });
}

/// Lists in [stalled] folders never answer (or answer when [releaseAll] is called, with [release]).
class _Stalling implements FileSystem {
  _Stalling(this._inner, this._stalled, {this.release = false});

  final FileSystem _inner;
  final Set<String> _stalled;
  final bool release;
  static final _waiting = <Completer<void>>[];

  static void releaseAll() {
    for (final c in _waiting) {
      c.complete();
    }
    _waiting.clear();
  }

  @override
  Future<String> home() => _inner.home();

  @override
  Future<List<FileEntry>> list(String directory) async {
    if (_stalled.contains(directory)) {
      final c = Completer<void>();
      if (release) _waiting.add(c);
      await c.future;
    }
    return _inner.list(directory);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
