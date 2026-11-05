import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/platform/content.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/data/files_providers.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/files/domain/transfers.dart';
import 'package:nux/features/files/presentation/files_tab.dart';
import 'package:nux/features/viewer/presentation/viewer_tab.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux_backend/nux_backend.dart';

import 'helpers.dart';

/// Another app's files, as the Android side of `nux/content` would serve them.
class FakeContent {
  FakeContent(this.pending);

  final List<Map<String, Object?>> pending;
  final files = <String, Uint8List>{};
  final _streams = <int, (String, int)>{};

  Future<Object?> handle(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
    final uri = args['uri'] as String?;
    switch (call.method) {
      case 'take':
        final list = [...pending];
        pending.clear();
        return list;
      case 'stat':
        return {'uri': uri, 'name': uri!.split('/').last, 'size': files[uri]!.length};
      case 'read':
        return files[uri];
      case 'write':
        files[uri!] = args['bytes']! as Uint8List;
        return null;
      case 'open':
        final id = _streams.length + 1;
        _streams[id] = (uri!, (args['start'] as int?) ?? 0);
        return id;
      case 'next':
        final id = args['id']! as int;
        final (u, at) = _streams[id]!;
        final data = files[u]!;
        if (at >= data.length) return null;
        _streams[id] = (u, data.length);
        return Uint8List.sublistView(data, at);
      case 'close':
        return null;
    }
    return null;
  }
}

void main() {
  const channel = MethodChannel('test/content');

  Future<ProviderContainer> start(WidgetTester tester, FakeContent fake, {List<Override> more = const []}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, fake.handle);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(
      overrides: [
        ...testOverrides(db: db, secrets: secrets),
        contentFilesProvider.overrideWith((ref) => ContentFiles(channel)),
        ...more,
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    return c;
  }

  testWidgets('"Open with nux": the file opens in an editor tab and saves back to the other app', (tester) async {
    const uri = 'content://example.files/doc/notes.txt';
    final fake = FakeContent([
      {
        'action': 'edit',
        'writable': true,
        'items': [
          {'uri': uri, 'name': 'notes.txt', 'size': 6},
        ],
      },
    ])..files[uri] = Uint8List.fromList(utf8.encode('hello\n'));
    final c = await start(tester, fake);
    final tab = c.read(workspaceProvider).current;
    expect(tab, isA<ViewerTab>());
    final viewer = tab! as ViewerTab;
    expect(viewer.title, 'notes.txt');
    for (var i = 0; i < 10 && viewer.document.bytes == null; i++) {
      await settle(tester);
    }
    expect(viewer.document.text, 'hello\n');

    viewer.setEditing(true);
    await settle(tester);
    viewer.editorFor(viewer.document.generation, viewer.document.text).$1.text = 'hello again\n';
    await tester.runAsync(() => viewer.save());
    expect(utf8.decode(fake.files[uri]!), 'hello again\n');
    // Not brought back after a restart: the other app's permission is gone by then.
    expect(c.read(tabFactoryProvider).restore({'id': 'x', 'kind': 'viewer', 'args': viewer.args}), isNull);
    // Leave no editor timers (cursor blink) running.
    viewer.setEditing(false);
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('"Share to nux": pick a host, go to the folder, Upload here', (tester) async {
    const uri = 'content://example.photos/1';
    final remote = Directory.systemTemp.createTempSync('nux-share-').resolveSymbolicLinksSync();
    addTearDown(() => Directory(remote).deleteSync(recursive: true));
    final fake = FakeContent([
      {
        'action': 'send',
        'items': [
          {'uri': uri, 'name': 'photo.jpg', 'size': 4},
        ],
      },
    ])..files[uri] = Uint8List.fromList([1, 2, 3, 4]);
    final manager = TransferManager(
      opener: (_) => () async => FsHandle(LocalFileSystem(remote), release: () {}),
      downloadsDir: () async => Directory('$remote/downloads'),
    );
    addTearDown(manager.dispose);
    final c = await start(tester, fake, more: [transferManagerProvider.overrideWithValue(manager)]);
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(remote), release: () {});

    for (var i = 0; i < 10 && find.text('Upload 1 file to').evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('Upload 1 file to'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Build server')));
    await settle(tester);
    await settle(tester);
    final files = c.read(workspaceProvider).current! as FilesTab;
    expect(find.text('1 file to upload: open the folder for it'), findsOneWidget);
    await tester.tap(find.text('Upload here'));
    // The upload reads through the (mocked) channel: let it run in turns with the test clock.
    for (var i = 0; i < 20 && manager.activeCount > 0; i++) {
      await settle(tester);
    }
    expect(manager.transfers.single.state, TransferState.done, reason: '${manager.transfers.single.error}');
    expect(File('${files.browser.path}/photo.jpg').readAsBytesSync(), [1, 2, 3, 4]);
    expect(find.text('Upload here'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
