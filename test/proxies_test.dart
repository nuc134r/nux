import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/proxy/data/proxy_repository.dart';
import 'package:nux/features/proxy/presentation/proxies_screen.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/zerotier/data/zerotier_service.dart';

import 'helpers.dart';

void main() {
  testWidgets('a proxy chooses what goes through it: hosts and ZeroTier; deleting it sends them directly', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    c.read(routerProvider).push(Routes.proxy('sample'));
    await settle(tester);
    expect(find.text('Edit proxy'), findsOneWidget);
    expect(find.text('proxy.example.com'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret');
    await tester.tap(find.text('Build server'));
    await tester.tap(find.text('ZeroTier traffic'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.descendant(of: find.byType(ProxyEditorScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text('Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);

    final repo = c.read(proxyRepositoryProvider);
    final saved = await tester.runAsync(() => repo.resolve('sample'));
    expect((saved!.username, saved.password), ('dev', 'secret'));
    expect((await tester.runAsync(() => repo.usedBy('sample')))!.map((h) => h.name), ['Build server']);
    expect(c.read(zeroTierServiceProvider).proxyId, 'sample');
    final settings = await tester.runAsync(() => c.read(settingsRepositoryProvider).load());
    expect(settings!.values[zeroTierProxySetting], 'sample');

    c.read(routerProvider).push(Routes.proxies);
    await settle(tester);
    expect(find.text('Office proxy'), findsOneWidget);
    expect(find.textContaining('1 host · ZeroTier'), findsOneWidget);

    await tester.tap(find.text('Office proxy'));
    await settle(tester);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('These will connect directly again: Build server, ZeroTier'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(find.text('Office proxy'), findsNothing);
    expect(await tester.runAsync(() => repo.usedBy('sample')), isEmpty);
    expect(await tester.runAsync(() => secrets.read(ProxyRepository.passwordSecretId('sample'))), isNull);
    expect(c.read(zeroTierServiceProvider).proxyId, isNull);
  });
}
