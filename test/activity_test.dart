import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/app/app.dart';
import 'package:nux/core/activity/activity_center.dart';
import 'package:nux/core/widgets/nux_menu.dart';
import 'package:nux/core/widgets/widgets.dart';
import 'package:tab_switcher/tab_switcher.dart' show TabCountButton;

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
}
