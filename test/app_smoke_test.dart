import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';

import 'helpers.dart';

/// Renders every route at phone and desktop widths with sample data: catches overflows, missing
/// translations and providers that throw. Add new routes to [Routes.all].
void main() {
  const sizes = {'phone': Size(360, 740), 'desktop': Size(1280, 800)};

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    for (final route in Routes.all) {
      testWidgets('$route renders on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final db = memoryDb();
        final secrets = MemorySecretStore();
        await tester.runAsync(() => insertSamples(db, secrets));
        final container = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
        await settle(tester);
        if (route != Routes.home) {
          container.read(routerProvider).push(route);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
        expect(find.byType(FloatingActionButton), findsNothing, reason: 'actions go in the ⋮ menu (PLAN: UI conventions)');

        // Unmount before the database closes so Drift streams are cancelled first.
        await tester.pumpWidget(const SizedBox());
        await settle(tester);
      });
    }
  }

  testWidgets('settings switch the language', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    container.read(routerProvider).go(Routes.settings);
    await settle(tester);
    await tester.tap(find.text('Language'));
    await settle(tester);
    await tester.tap(find.text('Русский'));
    await settle(tester);
    expect(find.text('Настройки'), findsOneWidget);
    expect(GoRouter.of(tester.element(find.text('Настройки'))).state.uri.path, Routes.settings);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
