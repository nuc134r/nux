import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/viewer/presentation/viewer_view.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux_backend/nux_backend.dart';
import 'package:re_editor/re_editor.dart';

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

    final c = ProviderContainer(
      overrides: testOverrides(db: db, secrets: secrets),
    );
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

  testWidgets('the keyboard coming up scrolls the cursor line to the middle of the editor', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-edit-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/long.txt')
      ..writeAsStringSync([for (var i = 1; i <= 200; i++) 'line $i'].join('\n'));

    final c = ProviderContainer(
      overrides: testOverrides(db: db, secrets: secrets),
    );
    addTearDown(c.dispose);
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(root.path), release: () {});
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final viewer = c.read(tabFactoryProvider).viewer('sample', file.path, line: 30);
    c.read(workspaceProvider).open(viewer);
    await settle(tester);
    viewer.setEditing(true);
    await settle(tester);

    // re_editor paints its text: ask its render object where the cursor's line is, from the top of the field.
    (double, double) cursorAndHeight() {
      final field =
          tester.allRenderObjects.firstWhere((r) => r.runtimeType.toString() == '_CodeFieldRender') as RenderBox;
      final offset = (field as dynamic).calculateTextPositionViewportOffset(
        viewer.editorFor(viewer.document.generation, viewer.document.text).$1.selection.extent,
      );
      return ((offset as Offset).dy + ((field as dynamic).lineHeight as double) / 2, field.size.height);
    }

    final (before, height) = cursorAndHeight();
    expect(before, lessThan(height), reason: 'visible before the keyboard');

    // The keyboard takes most of the screen: the line ends up in the middle of what is left.
    tester.view.viewInsets = FakeViewPadding(bottom: tester.view.physicalSize.height * .6);
    addTearDown(tester.view.resetViewInsets);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    final (after, shrunk) = cursorAndHeight();
    expect(shrunk, lessThan(height));
    expect(after, closeTo(shrunk / 2, 20));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a cursor moved in front of the line (space bar swipe) deletes nothing; backspace there joins lines', (
    tester,
  ) async {
    final editor = CodeLineEditingController.fromText('ab\ncd');
    addTearDown(editor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CodeEditor(controller: editor, autofocus: true)),
      ),
    );
    await tester.pump();
    editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 1);
    await tester.pump();
    final client = tester.testTextInput.log.lastWhere((c) => c.method == 'TextInput.setClient').arguments[0] as int;

    // The keyboard sees the line with an invisible prefix: '​cd', the cursor after 'c' at 2.
    Future<void> delta(Map<String, Object> d) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          client,
          {
            'deltas': [
              {
                'oldText': '​cd',
                'deltaText': '',
                'deltaStart': -1,
                'deltaEnd': -1,
                'selectionBase': 0,
                'selectionExtent': 0,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': -1,
                'composingExtent': -1,
                ...d,
              },
            ],
          },
        ]),
      ),
      (_) {},
    );

    await delta({}); // the cursor swiped to the very start, in front of the prefix
    await tester.pump();
    expect(editor.text, 'ab\ncd');
    expect(editor.selection, const CodeLineSelection.collapsed(index: 1, offset: 0));

    await delta({'oldText': '​cd', 'deltaStart': 0, 'deltaEnd': 1}); // backspace removes the prefix
    await tester.pump();
    expect(editor.text, 'abcd');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
