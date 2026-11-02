import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/terminal/domain/terminal_session.dart';
import 'package:nux/features/terminal/domain/terminal_tab.dart';
import 'package:nux/features/workspace/data/workspace.dart';
import 'package:nux/features/workspace/presentation/hosts_tab.dart';

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
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
