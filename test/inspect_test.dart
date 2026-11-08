import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/viewer/domain/inspect.dart';
import 'package:nux_backend/nux_backend.dart';

import 'local_runner.dart';

bool _has(String tool) => Process.runSync('sh', ['-c', 'command -v $tool']).exitCode == 0;

void main() {
  final runner = LocalRunner();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nux-inspect-');
    Directory('${dir.path}/src/docs').createSync(recursive: true);
    File('${dir.path}/src/readme.txt').writeAsStringSync('hello\n');
    File('${dir.path}/src/docs/guide with space.md').writeAsStringSync('# Guide\n');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ArchiveListing> list(String path) async =>
      parseArchiveListing(path, await runner.run(archiveListScript(path)));

  test('what the server is asked about, by name', () {
    expect(archiveFormatFor('a.tar.gz'), ArchiveFormat.tar);
    expect(archiveFormatFor('a.tgz'), ArchiveFormat.tar);
    expect(archiveFormatFor('app.apk'), ArchiveFormat.zip);
    expect(archiveFormatFor('x.7z'), ArchiveFormat.sevenZip);
    expect(archiveFormatFor('pkg.deb'), ArchiveFormat.deb);
    expect(archiveFormatFor('log.txt.gz'), ArchiveFormat.single);
    expect(archiveFormatFor('notes.txt'), isNull);
    expect(inspectTypeFor('app.db'), InspectType.database);
    expect(inspectTypeFor('clip.mkv'), InspectType.media);
    expect(inspectTypeFor('paper.pdf'), InspectType.pdf);
    expect(inspectTypeFor('IMG_1.HEIC'), InspectType.image);
    expect(inspectTypeFor('libfoo.so'), InspectType.executable);
    expect(inspectTypeFor('main.dart'), isNull);
    expect(archiveStem('backup.tar.gz'), 'backup');
    expect(archiveStem('data.json.gz'), 'data.json');
  });

  test('tar: lists, browses folders, opens one file, extracts all', () async {
    final archive = '${dir.path}/src.tar.gz';
    await Process.run('tar', ['-czf', archive, '-C', dir.path, 'src']);
    final listing = await list(archive);
    expect(listing.tool, 'tar');
    expect(listing.fileCount, 2);
    expect(listing.children('').map((n) => (n.name, n.isDir)), [('src', true)]);
    expect(listing.children('src').map((n) => n.name), ['docs', 'readme.txt']);
    expect(listing.children('src/docs').single.name, 'guide with space.md');
    expect(listing.children('src').last.size, 6);

    final temp = (await runner.run(archiveExtractToTempScript(archive, listing.tool, ['src/docs/guide with space.md'])))
        .stdout;
    addTearDown(() => Directory(temp).deleteSync(recursive: true));
    expect(File('$temp/src/docs/guide with space.md').readAsStringSync(), '# Guide\n');
    expect(File('$temp/src/readme.txt').existsSync(), isFalse, reason: 'only the file asked for');

    final r = await runner.run(archiveExtractAllScript(archive, listing.tool, '${dir.path}/out'));
    expect(r.ok, isTrue, reason: r.stderr);
    expect(File('${dir.path}/out/src/readme.txt').readAsStringSync(), 'hello\n');
  });

  test('zip: unzip, and Python when unzip is missing', () async {
    final archive = '${dir.path}/src.zip';
    if (!_has('zip')) return markTestSkipped('zip is not installed');
    await Process.run('zip', ['-qr', archive, 'src'], workingDirectory: dir.path);
    if (_has('unzip')) {
      final listing = await list(archive);
      expect(listing.tool, 'unzip');
      expect(listing.children('src').map((n) => n.name), ['docs', 'readme.txt']);
      final temp = (await runner.run(archiveExtractToTempScript(archive, 'unzip', ['src/readme.txt']))).stdout;
      addTearDown(() => Directory(temp).deleteSync(recursive: true));
      expect(File('$temp/src/readme.txt').readAsStringSync(), 'hello\n');
    }
    // Each fallback in turn, with the tools before it hidden.
    String without(List<String> tools) {
      var script = archiveListScript(archive);
      for (final t in tools) {
        script = script.replaceAll('command -v $t ', 'command -v no-such-$t ');
      }
      return script;
    }

    if (_has('7z') || _has('7zz') || _has('7za')) {
      final listing = parseArchiveListing(archive, await runner.run(without(['unzip', 'bsdtar'])));
      expect(listing.tool, '7z');
      expect(listing.children('src').map((n) => n.name), ['docs', 'readme.txt']);
      final temp = (await runner.run(archiveExtractToTempScript(archive, '7z', ['src/readme.txt']))).stdout;
      addTearDown(() => Directory(temp).deleteSync(recursive: true));
      expect(File('$temp/src/readme.txt').readAsStringSync(), 'hello\n');
    }
    if (_has('python3')) {
      final listing = parseArchiveListing(archive, await runner.run(without(['unzip', 'bsdtar', '7z', '7zz', '7za'])));
      expect(listing.tool, 'pyzip');
      expect(listing.children('src/docs').single.name, 'guide with space.md');
      final temp = (await runner.run(archiveExtractToTempScript(archive, 'pyzip', ['src/docs/guide with space.md'])))
          .stdout;
      addTearDown(() => Directory(temp).deleteSync(recursive: true));
      expect(File('$temp/src/docs/guide with space.md').existsSync(), isTrue);
    }
  });

  test('a single compressed file opens decompressed', () async {
    File('${dir.path}/log.txt').writeAsStringSync('line\n');
    await Process.run('gzip', ['${dir.path}/log.txt']);
    final archive = '${dir.path}/log.txt.gz';
    final listing = await list(archive);
    expect(listing.entries.single.path, 'log.txt');
    final temp = (await runner.run(archiveExtractToTempScript(archive, listing.tool, const []))).stdout;
    addTearDown(() => Directory(temp).deleteSync(recursive: true));
    expect(File('$temp/log.txt').readAsStringSync(), 'line\n');
  });

  test('deb packages list their files', () async {
    if (!_has('dpkg-deb')) return markTestSkipped('dpkg-deb is not installed');
    final root = Directory('${dir.path}/pkg/DEBIAN')..createSync(recursive: true);
    File('${root.path}/control').writeAsStringSync(
      'Package: demo\nVersion: 1.0\nArchitecture: all\nMaintainer: Demo <demo@example.com>\nDescription: demo\n',
    );
    Directory('${dir.path}/pkg/usr/share/demo').createSync(recursive: true);
    File('${dir.path}/pkg/usr/share/demo/a.txt').writeAsStringSync('a\n');
    final built = await Process.run('dpkg-deb', [
      '--build',
      '--root-owner-group',
      '${dir.path}/pkg',
      '${dir.path}/demo.deb',
    ]);
    if (built.exitCode != 0) return markTestSkipped('dpkg-deb --build failed: ${built.stderr}');
    final listing = await list('${dir.path}/demo.deb');
    expect(listing.tool, 'dpkg');
    expect(listing.children('usr/share/demo').single.name, 'a.txt');
    final temp = (await runner.run(
      archiveExtractToTempScript('${dir.path}/demo.deb', 'dpkg', listing.namesUnder('usr/share/demo/a.txt')),
    )).stdout;
    addTearDown(() => Directory(temp).deleteSync(recursive: true));
    expect(File('$temp/usr/share/demo/a.txt').readAsStringSync(), 'a\n');
  });

  test('bsdtar and 7z listings parse', () {
    const bsd =
        '@bsdtar\n'
        'drwxr-xr-x  0 user   staff       0 Jan  2 10:00 src/\n'
        '-rw-r--r--  0 user   staff       6 Jan  2  2025 src/readme.txt\n';
    final a = parseArchiveListing('a.tar', const CommandResult(exitCode: 0, stdout: bsd, stderr: ''));
    expect(a.children('src').single.size, 6);

    const sevenZip =
        '@7z\n'
        '7-Zip 23.01\n'
        'Listing archive: a.7z\n'
        '--\n'
        'Path = a.7z\n'
        'Type = 7z\n'
        '\n'
        '----------\n'
        'Path = src\n'
        'Size = 0\n'
        'Modified = 2026-01-02 10:00:00\n'
        'Attributes = D....\n'
        '\n'
        'Path = src/readme.txt\n'
        'Size = 6\n'
        'Modified = 2026-01-02 10:00:00\n'
        'Attributes = ....A\n';
    final b = parseArchiveListing('a.7z', const CommandResult(exitCode: 0, stdout: sevenZip, stderr: ''));
    expect(b.entries.map((e) => (e.path, e.isDir)), [('src', true), ('src/readme.txt', false)]);
    expect(
      () => parseArchiveListing('a.7z', const CommandResult(exitCode: 0, stdout: '@none\n', stderr: '')),
      throwsA(isA<MissingToolException>()),
    );
  });

  test('SQLite: tables, counts and rows, read-only', () async {
    if (!_has('python3') && !_has('sqlite3')) return markTestSkipped('needs sqlite3 or python3');
    final db = '${dir.path}/app.db';
    await Process.run('python3', [
      '-c',
      'import sqlite3,sys\n'
          'c=sqlite3.connect(sys.argv[1])\n'
          'c.execute("create table \\"my items\\" (id integer, name text, data blob)")\n'
          'c.executemany("insert into \\"my items\\" values (?,?,?)", [(i, "n%d" % i, b"xyz") for i in range(150)])\n'
          'c.execute("create view v as select 1")\n'
          'c.commit()',
      db,
    ]);
    Future<List<Map<String, Object?>>> query(String sql) async =>
        parseSqliteRows(await runner.run(sqliteQueryScript(db, sql)));
    final tables = await query(sqliteTablesQuery);
    expect(tables.map((t) => (t['name'], t['type'])), [('my items', 'table'), ('v', 'view')]);
    expect((await query(sqliteCountQuery('my items'))).single['n'], 150);
    final rows = await query(sqliteRowsQuery('my items', offset: 100));
    expect(rows.length, 50);
    expect(rows.first.keys, ['id', 'name', 'data']);
    expect(rows.first['name'], 'n100');
    expect(
      () async => parseSqliteRows(await runner.run(sqliteQueryScript(db, 'delete from "my items"'))),
      throwsA(isA<InspectException>()),
      reason: 'opened read-only',
    );
  });

  test('details: media from ffprobe, programs from readelf, PDF info', () async {
    if (_has('ffmpeg') && _has('ffprobe')) {
      final wav = '${dir.path}/tone.wav';
      await Process.run('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=duration=2',
        '-metadata',
        'title=Tone',
        wav,
      ]);
      final details = parseDetails((await runner.run(detailsScript(wav, InspectType.media))).stdout);
      final media = details.firstWhere((s) => s.kind == 'media');
      expect(media.pairs, contains(('Duration', '0:02')));
      expect(media.pairs.where((p) => p.$1 == 'Audio').single.$2, startsWith('pcm_s16le, 44100 Hz'));
      expect(media.pairs, contains(('Title', 'Tone')));
    }
    if (_has('readelf')) {
      final details = parseDetails((await runner.run(detailsScript('/bin/sh', InspectType.executable))).stdout);
      expect(details.firstWhere((s) => s.kind == 'elf').pairs.map((p) => p.$1), contains('Class'));
      expect(details.any((s) => s.kind == 'strings'), isTrue);
    }
    const pdf =
        '@@nux:file\nPDF document, version 1.4\n'
        '@@nux:pdfinfo\nTitle:          Report\nPages:          3\n'
        '@@nux:pdftext\nHello page one\n';
    final sections = parseDetails(pdf);
    expect(sections.map((s) => s.kind), ['file', 'pdf', 'pdfText']);
    expect(sections[1].pairs, [('Title', 'Report'), ('Pages', '3')]);
    expect(sections[2].text, 'Hello page one');
  });
}
