import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/files/presentation/files_tab.dart';
import 'package:nux/features/terminal/domain/terminal_tab.dart';
import 'package:nux/features/viewer/presentation/viewer_tab.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/features/workspace/data/workspace_access.dart';
import 'package:nux/features/workspace/data/workspace_repository.dart';
import 'package:nux_backend/nux_backend.dart';

import 'helpers.dart';

/// Runs commands on this machine (the drawer's git status in tests).
class LocalRunner implements ProcessRunner {
  @override
  Future<CommandResult> run(String command, {String? workingDirectory, Map<String, String>? environment}) async {
    final r = await Process.run('sh', ['-c', command], workingDirectory: workingDirectory, environment: environment);
    return CommandResult(exitCode: r.exitCode, stdout: r.stdout as String, stderr: r.stderr as String);
  }

  @override
  Future<RunningProcess> start(String command, {String? workingDirectory, Map<String, String>? environment}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('each workspace has its own tabs; the drawer shows its tree and git changes', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-ws-').resolveSymbolicLinksSync();
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    await tester.runAsync(() async {
      Directory('$root/lib').createSync();
      File('$root/lib/main.dart').writeAsStringSync('void main() {}\n');
      File('$root/README.md').writeAsStringSync('# app\n');
      final git = ['-c', 'user.name=t', '-c', 'user.email=t@example.com'];
      await Process.run('git', ['init', '-q', '-b', 'main'], workingDirectory: root);
      await Process.run('git', ['config', 'user.name', 't'], workingDirectory: root);
      await Process.run('git', ['config', 'user.email', 't@example.com'], workingDirectory: root);
      await Process.run('git', ['add', '.'], workingDirectory: root);
      await Process.run('git', [...git, 'commit', '-qm', 'init'], workingDirectory: root);
      File('$root/lib/main.dart').writeAsStringSync('void main() { print(1); }\n');
      File('$root/notes.md').writeAsStringSync('new\n');
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
    final terminal = c.read(tabFactoryProvider).terminal('sample');
    tabs.open(terminal);
    await settle(tester);

    final id = await tester.runAsync(
      () => c.read(workspaceRepositoryProvider).create(name: 'App', connectionId: 'sample', rootPath: root),
    );
    tabs.gridOpen = true;
    await settle(tester);
    await tester.tap(find.byTooltip('Workspaces'));
    await settle(tester);
    expect(find.text('No workspace'), findsOneWidget);
    await tester.tap(find.text('App'));
    await settle(tester);

    // The workspace starts with a file browser at its folder; the terminal waits in the other set.
    expect(c.read(workspaceSwitcherProvider).currentId, id);
    expect(tabs.tabs.single, isA<FilesTab>());
    expect(tabs.tabs.contains(terminal), isFalse);

    Finder drawer(String text) => find.descendant(of: find.byType(Drawer), matching: find.text(text));
    // Its drawer: the tree with the changed folder marked, and the changes.
    await settle(tester);
    expect(drawer('lib'), findsOneWidget);
    expect(drawer('README.md'), findsOneWidget);
    expect(drawer('main'), findsOneWidget, reason: 'the branch');
    await tester.tap(drawer('lib'));
    await settle(tester);
    expect(drawer('main.dart'), findsOneWidget);
    // Long press: details and actions for a file.
    await tester.longPress(drawer('main.dart'));
    await settle(tester);
    expect(find.text('Open in file browser'), findsOneWidget);
    expect(find.text('Open terminal here'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss
    await settle(tester);

    await tester.tap(drawer('Version control'));
    await settle(tester);
    expect(drawer('notes.md'), findsOneWidget);
    expect(drawer('U'), findsOneWidget);
    expect(drawer('M'), findsOneWidget);
    // A change opens its diff; Stage moves it to Staged; the commit box commits it.
    await tester.tap(drawer('main.dart'));
    await settle(tester);
    await settle(tester);
    expect(find.text('void main() { print(1); }'), findsOneWidget, reason: 'the added line');
    await tester.tap(find.widgetWithText(FilledButton, 'Stage'));
    await settle(tester);
    await settle(tester);
    expect(drawer('Staged  1'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(Drawer), matching: find.byType(TextField)), 'Print one');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Commit'));
    for (var i = 0; i < 25 && drawer('Staged  1').evaluate().isNotEmpty; i++) {
      await settle(tester);
    }
    expect(drawer('Staged  1'), findsNothing);
    final log = await tester.runAsync(() => Process.run('git', ['log', '-1', '--format=%s'], workingDirectory: root));
    expect((log!.stdout as String).trim(), 'Print one');
    Navigator.of(tester.element(find.byType(Drawer))).pop(); // close the drawer
    await settle(tester);

    // Quick open and Search in files, from the tab's menu (the header's ⋮, not a file row's).
    await tester.tap(find.byTooltip('More').first);
    await settle(tester);
    await tester.ensureVisible(find.text('Quick open'));
    await tester.tap(find.text('Quick open'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'readme');
    await settle(tester);
    // The finder is over the file browser, which lists README.md too: tap the finder's row.
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('README.md')));
    await settle(tester);
    expect((tabs.current! as ViewerTab).path, '$root/README.md');

    await tester.tap(find.byTooltip('More').last);
    await settle(tester);
    await tester.ensureVisible(find.text('Search in files'));
    await tester.tap(find.text('Search in files'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'print');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 5 && find.textContaining('main.dart').evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.textContaining('main.dart  lib'), findsOneWidget, reason: 'the file, then its folder');
    await tester.tap(find.text('1'));
    await settle(tester);
    expect((tabs.current! as ViewerTab).path, '$root/lib/main.dart');

    // Back outside workspaces: the terminal is there again, the same live tab.
    await tester.runAsync(() => c.read(workspaceSwitcherProvider).switchTo(null));
    await settle(tester);
    expect(tabs.tabs, contains(terminal));
    expect(tabs.tabs.whereType<ViewerTab>(), isEmpty);
    expect(tabs.tabs.whereType<TerminalTab>().single, same(terminal));
  });

  testWidgets('a merge stopped on a conflict: resolve it in the drawer, continue, see it in History', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-ws-').resolveSymbolicLinksSync();
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    Future<void> git(List<String> args) => Process.run('git', args, workingDirectory: root);
    await tester.runAsync(() async {
      await git(['init', '-q', '-b', 'main']);
      await git(['config', 'user.name', 't']);
      await git(['config', 'user.email', 't@example.com']);
      File('$root/a.txt').writeAsStringSync('one\n');
      await git(['add', '.']);
      await git(['commit', '-qm', 'init']);
      await git(['checkout', '-qb', 'other']);
      File('$root/a.txt').writeAsStringSync('theirs\n');
      await git(['commit', '-qam', 'Their change']);
      await git(['checkout', '-q', 'main']);
      File('$root/a.txt').writeAsStringSync('ours\n');
      await git(['commit', '-qam', 'Our change']);
      await git(['merge', 'other']); // stops on the conflict
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
    await tester.runAsync(
      () => c.read(workspaceRepositoryProvider).create(name: 'App', connectionId: 'sample', rootPath: root),
    );
    c.read(workspaceProvider).gridOpen = true;
    await settle(tester);
    await tester.tap(find.byTooltip('Workspaces'));
    await settle(tester);
    await tester.tap(find.text('App'));
    await settle(tester);
    await settle(tester);

    Finder drawer(String text) => find.descendant(of: find.byType(Drawer), matching: find.text(text));
    await tester.tap(drawer('Version control'));
    await settle(tester);
    expect(drawer('Merging'), findsOneWidget);
    expect(drawer('1 conflict to resolve'), findsOneWidget);

    await tester.tap(drawer('a.txt'));
    await settle(tester);
    expect(find.text('Resolve conflicts'), findsOneWidget);
    await tester.tap(find.text('Yours'));
    await settle(tester);
    await tester.tap(find.text('Save and mark resolved'));
    for (var i = 0; i < 10 && find.text('Resolve conflicts').evaluate().isNotEmpty; i++) {
      await settle(tester);
    }
    await settle(tester);
    expect(File('$root/a.txt').readAsStringSync(), 'ours\n');
    expect(drawer('No conflicts left'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.widgetWithText(FilledButton, 'Continue')));
    for (var i = 0; i < 10 && drawer('Merging').evaluate().isNotEmpty; i++) {
      await settle(tester);
    }
    expect(drawer('Merging'), findsNothing);
    final log = await tester.runAsync(() => Process.run('git', ['log', '-1', '--format=%P'], workingDirectory: root));
    expect((log!.stdout as String).trim().split(' '), hasLength(2), reason: 'a merge commit');

    // History lists the merge and both sides.
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.byTooltip('More')).first);
    await settle(tester);
    await tester.tap(find.text('History'));
    for (var i = 0; i < 5 && find.text('Their change').evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('Their change'), findsOneWidget);
    expect(find.text('Our change'), findsOneWidget);
  });

  testWidgets('Home lists the workspaces on its second page and opens one', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-home-').resolveSymbolicLinksSync();
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    final c = ProviderContainer(
      overrides: testOverrides(db: db, secrets: secrets),
    );
    addTearDown(c.dispose);
    c.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(root), release: () {});
    final id = await tester.runAsync(
      () => c.read(workspaceRepositoryProvider).create(name: 'Site', connectionId: 'sample', rootPath: root),
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    expect(find.text('Home'), findsWidgets);
    await tester.tap(find.text('Workspaces'));
    await settle(tester);
    await tester.tap(find.text('Site'));
    await settle(tester);
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(c.read(workspaceSwitcherProvider).currentId, id);
    expect(c.read(workspaceProvider).tabs.single, isA<FilesTab>());
  });

  testWidgets('empty overview: one Home button; drawer without a workspace explains it once', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(
      overrides: testOverrides(db: db, secrets: secrets),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final tabs = c.read(workspaceProvider);
    tabs.gridOpen = true;
    await settle(tester);
    await tabs.close(tabs.tabs.single, force: true);
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Home'), findsOneWidget, reason: 'the footer goes with the last tab');

    await tester.tap(find.byTooltip('Workspaces'));
    await settle(tester);
    expect(find.text('No workspace'), findsOneWidget);
    expect(find.textContaining('A workspace is a folder'), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.byTooltip('More')), findsNothing);
  });
}
