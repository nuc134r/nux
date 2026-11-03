import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tab_switcher/tab_switcher.dart';

import 'helpers.dart';

void main() {
  testWidgets('live tabs keep their state, parked ones are rebuilt', (tester) async {
    final c = TabSwitcherController(keepAlive: 1);
    addTearDown(c.dispose);
    final a = CounterTab('a'), b = CounterTab('b'), d = CounterTab('d');
    c.open(a);
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('a:0'));
    await tester.pump();
    expect(find.text('a:1'), findsOneWidget);

    c.open(b);
    await tester.pump();
    expect(find.text('b:0'), findsOneWidget);
    c.select(a);
    await tester.pump();
    expect(find.text('a:1'), findsOneWidget, reason: 'a stayed live');

    c.open(d); // live: d, a — b is parked
    await tester.pump();
    expect(b.parked, 1);
    c.select(b); // live: b, d — a is parked
    await tester.pump();
    expect(b.resumed, 1);
    expect(a.parked, 1);
    c.select(a);
    await tester.pump();
    expect(find.text('a:0'), findsOneWidget, reason: 'a was parked, so its widget state is gone');
  });

  testWidgets('grid: open with the count button, select, close with undo', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'));
    await tester.pumpWidget(app(c));
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(TabCountButton));
    await tester.pump();
    expect(c.gridOpen, isTrue);
    expect(find.text('grid'), findsOneWidget);
    expect(find.text('Tab a'), findsOneWidget);

    await tester.tap(find.text('Tab a'));
    await tester.pump();
    expect(c.current?.id, 'a');
    expect(c.gridOpen, isFalse);

    c.gridOpen = true;
    await tester.pump();
    await tester.tap(find.descendant(of: find.ancestor(of: find.text('Tab b'), matching: find.byType(Row)).first, matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(c.length, 1);
    expect(find.text('Closed Tab b'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(c.length, 2);
  });

  testWidgets('swiping a card away closes it unless closing is refused', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    final a = CounterTab('a', unsaved: true);
    c
      ..open(a)
      ..open(CounterTab('b'))
      ..confirmClose = ((_) async => false)
      ..gridOpen = true;
    await tester.pumpWidget(app(c));
    await tester.fling(find.text('Tab a'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(c.tabs, contains(a));
    await tester.fling(find.text('Tab b'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(c.length, 1);
  });

  testWidgets('swiping the header switches tabs; swiping it down opens the grid', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'));
    c.select(c.tabs.first);
    await tester.pumpWidget(app(c));
    expect(find.text('header a'), findsOneWidget);

    await tester.fling(find.text('header a'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(c.current?.id, 'b');
    expect(find.text('b:0'), findsOneWidget);

    await tester.fling(find.text('header b'), const Offset(0, 200), 1500);
    await tester.pumpAndSettle();
    expect(c.gridOpen, isTrue);
  });

  testWidgets('opening a tab shows its content, not the previous tab', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c.open(CounterTab('a'));
    await tester.pumpWidget(app(c));
    c.open(CounterTab('b'));
    await tester.pump();
    await tester.pump();
    expect(find.text('header b'), findsOneWidget);
    expect(find.text('b:0').hitTestable(), findsOneWidget);
    expect(find.text('a:0').hitTestable(), findsNothing);
  });

  testWidgets('back closes the grid first', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..gridOpen = true;
    await tester.pumpWidget(app(c));
    final dynamic state = tester.state(find.byType(Navigator));
    await state.maybePop();
    await tester.pump();
    expect(c.gridOpen, isFalse);
  });

  testWidgets('wide screens show a tab strip', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'));
    await tester.pumpWidget(app(c));
    expect(find.text('Tab a'), findsOneWidget);
    await tester.tap(find.text('Tab a'));
    await tester.pump();
    expect(c.current?.id, 'a');
    expect(find.text('a:0'), findsOneWidget);
  });

  testWidgets('opening a tab from the grid does not slide the header in', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'))
      ..open(CounterTab('c')); // current: c, the last page
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    Future<void> openFromGrid(String id) async {
      c.gridOpen = true;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab $id').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(find.text('header $id')).dx, 0, reason: 'frame $i: the header is in place at once');
      }
    }

    // Closing tabs in the grid leaves the old page out of range: it used to spring back into place.
    c.gridOpen = true;
    await tester.pumpAndSettle();
    await c.close(c.tabs[2], force: true);
    await c.close(c.tabs[1], force: true);
    await openFromGrid('a');

    c.open(CounterTab('d'));
    await tester.pumpAndSettle();
    await openFromGrid('a'); // another page than the one shown before the grid
  });
}
