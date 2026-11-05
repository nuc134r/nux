import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/viewer/presentation/viewer_view.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux_backend/nux_backend.dart';

import 'helpers.dart';

void main() {
  testWidgets('editing: the key bar types, and a file changed on the server shows the diff before overwriting', (
    tester,
  ) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-edit-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/a.txt')..writeAsStringSync('one\ntwo\nthree\n');

    final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(c.dispose);
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(root.path), release: () {});
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final viewer = c.read(tabFactoryProvider).viewer('sample', file.path);
    c.read(workspaceProvider).open(viewer);
    await settle(tester);
    // The status bar: where the cursor is, the encoding and the line endings.
    expect(find.text('Ln 1, Col 1'), findsOneWidget);
    expect(find.text('UTF-8'), findsOneWidget);
    expect(find.text('LF'), findsOneWidget);
    viewer.setEditing(true);
    await settle(tester);

    expect(find.byType(EditorKeyBar), findsOneWidget);
    await tester.tap(find.text('{'));
    await settle(tester);
    expect(viewer.editedText, startsWith('{'));
    expect(viewer.dirty, isTrue);

    // Someone else changes the file; saving now asks, and can show what differs.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1100)); // a different mtime
      file.writeAsStringSync('one\nTWO\nthree\n');
    });
    final saving = viewer.onSave!();
    await settle(tester);
    await tester.tap(find.text('Show changes'));
    await settle(tester);
    await settle(tester);
    expect(find.byType(DiffView), findsOneWidget);
    expect(find.text('TWO'), findsOneWidget, reason: "the server's line");
    await tester.tap(find.text('Overwrite'));
    await settle(tester);
    await tester.runAsync(() => saving);
    expect(file.readAsStringSync(), startsWith('{one'));

    // Leave no editor timers (cursor blink) or snackbars running.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
