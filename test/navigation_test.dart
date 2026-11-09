import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/app/router.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/presentation/appearance_screen.dart';
import 'package:nux/features/settings/presentation/settings_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('screens open with a short fade and slide, and close the same way', (tester) async {
    final db = memoryDb();
    await tester.runAsync(() => insertSamples(db, MemorySecretStore()));
    final c = ProviderContainer(overrides: testOverrides(db: db));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);

    double opacity(Finder screen) => tester
        .widget<FadeTransition>(find.ancestor(of: screen, matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    for (final (route, type) in [(Routes.settings, SettingsScreen), (Routes.appearance, AppearanceScreen)]) {
      c.read(routerProvider).push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final screen = find.byType(type);
      expect(opacity(screen), inExclusiveRange(0, 1), reason: '$route fades in');
      expect(tester.getRect(screen).left, greaterThan(0), reason: '$route slides in from the right');
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(screen), 1);
      expect(tester.getRect(screen).left, 0);
    }

    // Back fades the screen out again.
    c.read(routerProvider).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(find.byType(AppearanceScreen)), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppearanceScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
