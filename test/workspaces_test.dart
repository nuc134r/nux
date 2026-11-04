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
    await tester.tap(drawer('Version control'));
    await settle(tester);
    expect(drawer('notes.md'), findsOneWidget);
    expect(drawer('U'), findsOneWidget);
    expect(drawer('M'), findsOneWidget);
    await tester.tap(drawer('main.dart'));
    await settle(tester);
    expect(tabs.current, isA<ViewerTab>());

    // Back outside workspaces: the terminal is there again, the same live tab.
    await tester.runAsync(() => c.read(workspaceSwitcherProvider).switchTo(null));
    await settle(tester);
    expect(tabs.tabs, contains(terminal));
    expect(tabs.tabs.whereType<ViewerTab>(), isEmpty);
    expect(tabs.tabs.whereType<TerminalTab>().single, same(terminal));
  });
}
