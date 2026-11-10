import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/data/settings_repository.dart';
import 'package:nux/features/zerotier/presentation/zerotier_details.dart';

import 'helpers.dart';

// The node stays off: widget tests never call libzt.
void main() {
  testWidgets('a network opens its details; ⋮ opens the node\'s', (tester) async {
    final db = memoryDb();
    await tester.runAsync(() => insertSamples(db, MemorySecretStore()));
    final c = ProviderContainer(overrides: testOverrides(db: db));
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(settingsRepositoryProvider).set('zerotier.networks', '["8056c2e21c000001"]'));
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    c.read(routerProvider).push(Routes.zerotier);
    await settle(tester);

    await tester.tap(find.text('8056c2e21c000001'));
    await settle(tester);
    expect(find.byType(ZeroTierNetworkScreen), findsOneWidget);
    expect(find.text('Network ID'), findsOneWidget);
    expect(find.text('Turn the node on to see the details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Node details'));
    await settle(tester);
    expect(find.byType(ZeroTierNodeScreen), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
