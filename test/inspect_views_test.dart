import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/viewer/presentation/inspect_views.dart';
import 'package:nux/features/viewer/presentation/viewer_tab.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/features/workspace/data/workspace_access.dart';
import 'package:nux_backend/nux_backend.dart';

import 'helpers.dart';
import 'local_runner.dart';

bool _has(String tool) => Process.runSync('sh', ['-c', 'command -v $tool']).exitCode == 0;

/// Pumps until [finder] shows: the previews run real commands, which need real time.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (finder.evaluate().isEmpty) {
    debugPrint([for (final e in find.byType(Text).evaluate()) (e.widget as Text).data].join(' | '));
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets('archives, databases, media details and SVG in the viewer', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-preview-').path;
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    await tester.runAsync(() async {
      Directory('$root/src/docs').createSync(recursive: true);
      File('$root/src/readme.txt').writeAsStringSync('hello\n');
      File('$root/src/docs/guide.md').writeAsStringSync('# Guide\n');
      await Process.run('tar', ['-czf', '$root/src.tar.gz', '-C', root, 'src']);
      File('$root/logo.svg').writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>',
      );
      if (_has('python3')) {
        await Process.run('python3', [
          '-c',
          'import sqlite3,sys\nc=sqlite3.connect(sys.argv[1])\n'
              'c.execute("create table users (id integer, name text)")\n'
              'c.execute("insert into users values (1, \'Ada\')")\nc.commit()',
          '$root/app.db',
        ]);
      }
    });

    final c = ProviderContainer(
      overrides: [
        ...testOverrides(db: db, secrets: secrets),
        workspaceOpenerProvider.overrideWithValue(
          (id) async => WorkspaceAccess(fs: LocalFileSystem(root), runner: LocalRunner(), release: () {}),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(root), release: () {});
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final tabs = c.read(workspaceProvider);

    // An archive lists its files; folders open; a file opens in a new tab, unpacked on the server.
    final archive = c.read(tabFactoryProvider).viewer('sample', '$root/src.tar.gz');
    tabs.open(archive);
    await _waitFor(tester, find.text('src'));
    expect(find.byType(ArchiveView), findsOneWidget);
    expect(find.text('2 files'), findsOneWidget);
    await tester.tap(find.text('src'));
    await tester.pump();
    expect(find.text('docs'), findsOneWidget);
    expect(find.text('readme.txt'), findsOneWidget);
    await tester.tap(find.text('readme.txt'));
    for (var i = 0; i < 100 && tabs.current == archive; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    debugPrint(
      'SNACK ${find.byType(SnackBar).evaluate().map((e) => ((e.widget as SnackBar).content as Text).data)} busy=${archive.busy} tabs=${tabs.tabs.map((t) => t.title)}',
    );
    final opened = tabs.current! as ViewerTab;
    expect(opened.path, endsWith('/src/readme.txt'));
    addTearDown(() => Directory(File(opened.path).parent.parent.path).deleteSync(recursive: true));

    // Extract all: a folder named after the archive, next to it.
    tabs.select(archive);
    await settle(tester);
    await tester.runAsync(() async => archive.onExtractAll!());
    expect(File('$root/src/src/readme.txt').existsSync(), isTrue);

    // ⋮ → Show bytes falls back to the hex view.
    archive.showBytesInstead();
    await tester.pump();
    expect(find.byType(ArchiveView), findsNothing);

    // SVG draws; Show source shows the text.
    final svg = c.read(tabFactoryProvider).viewer('sample', '$root/logo.svg');
    tabs.open(svg);
    await _waitFor(tester, find.byType(SvgPicture));
    svg.setRendered(false);
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);

    // A database lists its tables; one opens as rows.
    if (_has('python3') || _has('sqlite3')) {
      tabs.open(c.read(tabFactoryProvider).viewer('sample', '$root/app.db'));
      await _waitFor(tester, find.text('users'));
      await _waitFor(tester, find.text('1 row'));
      await tester.tap(find.text('users'));
      await _waitFor(tester, find.text('Ada'));
      expect(find.text('name'), findsOneWidget);
    }

    // A program's details from the server.
    if (_has('readelf')) {
      await tester.runAsync(() async => File('/bin/sh').copySync('$root/tool.bin'));
      final bin = c.read(tabFactoryProvider).viewer('sample', '$root/tool.bin');
      tabs.open(bin);
      await _waitFor(tester, find.textContaining('00000000'));
      bin.showDetails = true;
      bin.document.load();
      await _waitFor(tester, find.text('Program'));
      expect(find.byType(DetailsView), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
