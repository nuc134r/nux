import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/background/background_access.dart';
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

  testWidgets('settings show what Android does not allow in the background, with buttons to fix it', (tester) async {
    final access = _DeniedAccess();
    final container = ProviderContainer(overrides: [
      ...testOverrides(),
      backgroundAccessProvider.overrideWithValue(access),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NuxApp()));
    await settle(tester);
    container.read(routerProvider).go(Routes.settings);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Battery optimisation'), 200);
    await settle(tester);
    expect(find.text('Off: background connections run without their notification'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Allow'), findsNWidgets(2));

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Allow').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow').first);
    await settle(tester);
    expect(access.asked, 1);
    expect(find.text('Turn them on in Android settings: Apps → nux → Notifications'), findsOneWidget,
        reason: 'Android stopped showing the prompt');

    access.battery = true;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Allow').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow').last);
    await settle(tester);
    expect(find.text('Unrestricted: Android leaves background connections running'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}

class _DeniedAccess implements BackgroundAccess {
  int asked = 0;
  bool battery = false;

  @override
  Future<bool> notificationsAllowed() async => false;

  @override
  Future<bool> allowNotifications() async {
    asked++;
    return false;
  }

  @override
  Future<bool> batteryUnrestricted() async => battery;

  @override
  Future<void> allowUnrestrictedBattery() async {}
}
