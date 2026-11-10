import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/app/theme.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/presentation/appearance_screen.dart';
import 'package:nux/features/settings/presentation/settings_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets("screens open and close with Android's page transition", (tester) async {
    final db = memoryDb();
    await tester.runAsync(() => insertSamples(db, MemorySecretStore()));
    final c = ProviderContainer(overrides: testOverrides(db: db));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    // The route's own animation: mid-way shortly after a push, done once it has settled.
    double progress(Type screen) => ModalRoute.of(tester.element(find.byType(screen)))!.animation!.value;

    for (final (route, type) in [(Routes.settings, SettingsScreen), (Routes.appearance, AppearanceScreen)]) {
      c.read(routerProvider).push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(progress(type), inExclusiveRange(0, 1), reason: '$route animates in');
      await tester.pump(const Duration(milliseconds: 160));
      expect(progress(type), 1, reason: '$route is done within 200 ms');
    }
    expect(
      Theme.of(tester.element(find.byType(AppearanceScreen))).pageTransitionsTheme.builders[TargetPlatform.android],
      isA<QuickZoomPageTransitionsBuilder>(),
    );

    c.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress(AppearanceScreen), inExclusiveRange(0, 1), reason: 'animates out');
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
