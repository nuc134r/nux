import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/activity/activity_center.dart';
import 'package:nux/core/widgets/nux_menu.dart';
import 'package:nux/core/widgets/widgets.dart';
import 'package:tab_switcher/tab_switcher.dart' show TabCountButton;

import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/workspace/data/tab_factory.dart';
import 'package:nux/features/workspace/data/workspace.dart';

import 'package:nux/features/updates/data/update_service.dart';
import 'package:nux/features/updates/domain/release.dart';
import 'package:nux/features/updates/presentation/version_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('Activity: the tab count shows what runs or is new; ⋮ → Activity lists it, with Cancel', (tester) async {
    final c = ProviderContainer(overrides: testOverrides());
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final center = c.read(activityCenterProvider);

    var cancelled = false;
    final pull = center.start(ActivitySource.git, 'git pull', subtitle: 'demo', cancel: () => cancelled = true);
    center.update(pull, progress: .4, subtitle: 'Receiving objects: 40%');
    center.event(ActivitySource.forwarding, 'Forwarding Database stopped', state: ActivityState.failed);
    await tester.pump();
    expect(
      find.descendant(of: find.byType(TabCountButton), matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
      reason: 'something runs',
    );

    await tester.tap(find.byType(NuxMenuButton).first);
    await settle(tester);
    expect(find.text('1 running'), findsOneWidget);
    await tester.tap(find.text('Activity'));
    await settle(tester);
    expect(find.text('git pull'), findsOneWidget);
    expect(find.text('Receiving objects: 40%'), findsOneWidget);
    expect(find.text('Forwarding Database stopped'), findsOneWidget);
    expect(center.unread, 0, reason: 'seen');
    await tester.tap(find.byTooltip('Cancel'));
    expect(cancelled, isTrue);

    // A snackbar's message lands here too.
    center.finish(pull, ActivityState.done);
    showSnack(tester.element(find.text('Activity')), 'Saved notes.md');
    await settle(tester);
    expect(find.text('Saved notes.md'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('tab overview: Activity next to Home; ⋮ → Close all tabs asks, then closes them', (tester) async {
    final db = memoryDb();
    final secrets = MemorySecretStore();
    await tester.runAsync(() => insertSamples(db, secrets));
    final c = ProviderContainer(overrides: testOverrides(db: db, secrets: secrets));
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    final tabs = c.read(workspaceProvider);
    tabs.open(c.read(tabFactoryProvider).hosts());
    tabs.gridOpen = true;
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Home'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Activity'));
    await settle(tester);
    expect(find.text('Running'), findsNothing);
    Navigator.of(tester.element(find.text('Activity').last)).pop();
    await settle(tester);

    await tester.tap(find.byType(NuxMenuButton).first);
    await settle(tester);
    await tester.tap(find.text('Close all tabs'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Close all tabs'));
    await settle(tester);
    expect(tabs.isEmpty, isTrue);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('an update is an Activity entry (no card on Home); tapping it opens the update screen', (tester) async {
    final c = ProviderContainer(
      overrides: [
        ...testOverrides(),
        availableUpdateProvider.overrideWith(
          (ref) async => const Release(version: '9.9.9', pageUrl: 'https://example.com/r', apks: {}),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const NuxApp()));
    await settle(tester);
    await settle(tester);
    expect(find.text('Update'), findsNothing, reason: 'no update card');
    await tester.tap(find.byType(NuxMenuButton).first);
    await settle(tester);
    await tester.tap(find.text('Activity'));
    await settle(tester);
    await tester.tap(find.text('nux 9.9.9 is available'));
    await settle(tester);
    expect(find.byType(VersionScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
