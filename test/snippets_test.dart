import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/terminal/domain/snippets.dart';
import 'package:nux/features/terminal/presentation/snippets_view.dart';

import 'helpers.dart';

void main() {
  test('snippets round-trip through JSON; anything unreadable means the presets', () {
    const list = [Snippet('Disk', 'df -h'), Snippet('Two lines', 'cd /srv\nls')];
    expect(decodeSnippets(encodeSnippets(list)), list);
    expect(decodeSnippets(null), isNull);
    expect(decodeSnippets('not json'), isNull);
    expect(decodeSnippets('[{"name":"x"},{"name":"y","command":"ls"}]'), [const Snippet('y', 'ls')]);
    expect(snippetPresets.map((p) => p.$1).toSet().length, snippetPresets.length);
  });

  Future<ProviderContainer> app(WidgetTester tester) async {
    final db = memoryDb();
    await tester.runAsync(() => insertSamples(db, MemorySecretStore()));
    final c = ProviderContainer(overrides: testOverrides(db: db));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    return c;
  }

  testWidgets('the sheet runs a snippet on tap and only types it on a long press', (tester) async {
    final c = await app(tester);
    final sent = <String>[];
    final context = tester.element(find.byType(Scaffold).first);
    showSnippetsSheet(context, send: sent.add);
    await settle(tester);
    expect(find.text('Disk space'), findsOneWidget);
    await tester.tap(find.text('Disk space'));
    await settle(tester);
    expect(sent, ['df -h\r']);
    showSnippetsSheet(context, send: sent.add);
    await settle(tester);
    await tester.longPress(find.text('Processes by memory'));
    await settle(tester);
    expect(sent.last, 'ps aux --sort=-%mem | head -15');
    expect(c.read(appSettingsProvider).value?.values[SettingKeys.terminalSnippets], isNull, reason: 'presets');
  });

  testWidgets('Settings → Snippets: add, edit, delete, back to the presets', (tester) async {
    final c = await app(tester);
    c.read(routerProvider).push(Routes.snippets);
    await settle(tester);
    expect(find.text('Disk space'), findsOneWidget);

    Future<List<Snippet>> saved() async {
      // Let the write reach the database.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      final s = await tester.runAsync(() => c.read(settingsRepositoryProvider).load());
      return decodeSnippets(s!.values[SettingKeys.terminalSnippets]) ?? const [];
    }

    await tester.tap(find.text('Add snippet'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Nginx log');
    await tester.enterText(find.widgetWithText(TextField, 'Command'), 'tail -n 50 /var/log/nginx/error.log');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect((await saved()).last, const Snippet('Nginx log', 'tail -n 50 /var/log/nginx/error.log'));
    expect((await saved()).length, snippetPresets.length + 1);

    await tester.tap(find.text('Disk space'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect((await saved()).any((s) => s.name == 'Disk space'), isFalse);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Reset to presets').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset to presets'));
    await settle(tester);
    expect(await saved(), isEmpty);
    expect(find.text('Disk space'), findsOneWidget);
    expect(find.text('Nginx log'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
