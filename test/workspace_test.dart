import 'dart:io';

import 'package:flterm/flterm.dart' show TerminalView;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/terminal/domain/terminal_session.dart';
import 'package:nux/features/terminal/domain/terminal_tab.dart';
import 'package:nux/features/files/presentation/files_tab.dart';
import 'package:nux/features/viewer/presentation/viewer_tab.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/features/workspace/presentation/hosts_tab.dart';

import 'package:nux_backend/nux_backend.dart';

import 'helpers.dart';

void main() {
  testWidgets('first start opens the hosts tab; a host opens a terminal tab; tabs are restored', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));

    var container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);

    final tabs = container.read(workspaceProvider);
    expect(tabs.tabs.single, isA<HostsTab>());
    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Work'), findsOneWidget, reason: 'group header');
    expect(find.text('dev@build.example.com'), findsOneWidget);

    // The sample host is unreachable from the test, and the refusing prompter declines everything:
    // the terminal shows the failure instead of hanging.
    await tester.tap(find.text('Build server'));
    await settle(tester);
    expect(tabs.length, 2);
    final terminal = tabs.current! as TerminalTab;
    expect(terminal.title, 'Build server');
    for (var i = 0; i < 30 && terminal.session.state == TerminalState.connecting; i++) {
      await settle(tester);
    }
    expect(terminal.session.state, isNot(TerminalState.connecting));

    // Let the debounced session save run, then start over with the same database.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await settle(tester);
    final saved = await tester.runAsync(() => container.read(settingsRepositoryProvider).load());
    expect(saved!.values['tabs.session'], contains('terminal'));
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    container.dispose();

    container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    final restored = container.read(workspaceProvider);
    expect(restored.tabs.map((t) => t.runtimeType), [HostsTab, TerminalTab]);
    expect(restored.current, isA<TerminalTab>());

    // Files and viewer tabs save their place too.
    final factory = container.read(tabFactoryProvider);
    final files = factory.restore({'kind': 'files', 'id': 'f1', 'args': {'connectionId': 'sample', 'path': '/srv'}}) as FilesTab;
    expect(files.browser.path, '/srv');
    expect(files.args, {'connectionId': 'sample', 'path': '/srv'});
    final viewer = factory.restore({'kind': 'viewer', 'id': 'v1', 'args': {'connectionId': 'sample', 'path': '/etc/hosts'}}) as ViewerTab;
    expect(viewer.title, 'hosts');
    files.dispose();
    viewer.dispose();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('the ⋮ menu: tab entries and Settings in a tab, app screens in the grid, text size', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);

    await tester.tap(find.text('Build server'));
    await settle(tester);
    expect(container.read(workspaceProvider).current, isA<TerminalTab>());

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Port forwarding'), findsNothing);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    // A real tap leaves an ink animation running, which starves flterm's idle-priority task under the
    // test clock (pump never returns); press the button directly.
    tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.add), matching: find.byType(IconButton)).last).onPressed!();
    await settle(tester);
    final settings = await tester.runAsync(() => container.read(settingsRepositoryProvider).load());
    expect(settings!.terminalFontSize, 15);
    expect(find.text('15'), findsOneWidget, reason: 'the menu stays open and updates');
    await tester.tapAt(const Offset(10, 500)); // the barrier
    await settle(tester);
    expect(find.text('Text size'), findsNothing);

    container.read(workspaceProvider).gridOpen = true;
    await settle(tester);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    for (final label in ['Hosts', 'Quick connect', 'Port forwarding', 'Keys', 'ZeroTier', 'Settings']) {
      expect(find.descendant(of: find.byType(Material).last, matching: find.text(label)), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('ZeroTier').last);
    await settle(tester);
    expect(find.text('Start with nux'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('Back in a file opened from the files tab closes it and returns there; in edit mode it leaves edit mode', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final root = Directory.systemTemp.createTempSync('nux-back-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/sub').createSync();
    File('${root.path}/sub/notes.txt').writeAsStringSync('hello\n');

    final container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(container.dispose);
    container.read(tabFactoryProvider).openOverride = () async => FsHandle(LocalFileSystem(root.path), release: () {});
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    final tabs = container.read(workspaceProvider);
    final files = container.read(tabFactoryProvider).files('sample', path: '${root.path}/sub');
    tabs.open(files);
    await settle(tester);
    expect(find.text('notes.txt'), findsOneWidget);

    Future<void> openNotes() async {
      await tester.tap(find.text('notes.txt'));
      await settle(tester);
      expect(tabs.current, isA<ViewerTab>());
    }

    await openNotes();
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(tabs.current, same(files));
    expect(tabs.tabs.whereType<ViewerTab>(), isEmpty);
    expect(files.browser.path, '${root.path}/sub', reason: 'the files tab did not go up');

    await openNotes();
    final viewer = tabs.current! as ViewerTab;
    viewer.setEditing(true);
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(viewer.editing, isFalse);
    expect(tabs.current, same(viewer));

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('installing a key shows progress on its row, then the result in a snackbar', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    container.read(routerProvider).push(Routes.key('sample'));
    await settle(tester);

    await tester.tap(find.text('Install on a server'));
    await settle(tester);
    await tester.tap(find.text('Build server'));
    await tester.pump();
    expect(find.text('Installing the key on Build server…'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'progress is on the row, not in a snackbar');

    // The sample host does not exist: the failure ends up in a snackbar and the row is back.
    for (var i = 0; i < 30 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Installing the key on Build server…'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('tapping the terminal shows the soft keyboard again', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    await tester.tap(find.text('Build server'));
    await settle(tester);

    // As if Back had hidden the keyboard: the terminal keeps focus, so only an explicit show helps.
    tester.testTextInput.log.clear();
    await tester.tapAt(tester.getCenter(find.byType(TerminalView)));
    await tester.pump();
    expect(tester.testTextInput.log.map((c) => c.method), contains('TextInput.show'));

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
