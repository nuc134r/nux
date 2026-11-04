import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/browser/presentation/browser_tab.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';

import 'helpers.dart';

void main() {
  testWidgets('a browser tab: address bar, restored with its page, Back/Forward in ⋮', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    final tab = BrowserTab(url: '');
    c.read(workspaceProvider).open(tab);
    await settle(tester);
    expect(find.text('Web pages cannot be shown here'), findsOneWidget, reason: 'no web view in tests');
    expect(find.byType(TextField), findsNothing, reason: 'no address field on the page');
    // Tapping the title in the header asks for the address.
    await tester.tap(find.text('Browser').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'localhost:8080');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await settle(tester);
    expect(tab.url, 'http://localhost:8080');
    expect(tab.title, 'localhost');

    final restored = c.read(tabFactoryProvider).restore(tab.toJson());
    expect(restored, isA<BrowserTab>());
    expect((restored! as BrowserTab).url, 'http://localhost:8080');
    restored.dispose();

    await tester.tap(find.byTooltip('More').first);
    await settle(tester);
    expect(find.byTooltip('Back'), findsOneWidget, reason: 'Back, Forward and Reload on one row');
    expect(find.byTooltip('Reload'), findsOneWidget);
    expect(find.text('Open in another app'), findsOneWidget);
  });
}
