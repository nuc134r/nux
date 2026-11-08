import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
    await tester.pumpAndSettle(); // the grid zooms out from the current tab
    expect(c.gridOpen, isTrue);
    expect(find.text('grid'), findsOneWidget);
    expect(find.text('Tab a'), findsOneWidget);

    await tester.tap(find.text('Tab a'));
    await tester.pumpAndSettle(); // the card zooms in, then the tab shows
    expect(c.current?.id, 'a');
    expect(c.gridOpen, isFalse);

    c.gridOpen = true;
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text('Tab b'), matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.close),
      ),
    );
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

  testWidgets('a slow drag down on the header opens the overview before the finger lifts', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c.open(CounterTab('a'));
    await tester.pumpWidget(app(c));
    final g = await tester.startGesture(tester.getCenter(find.text('header a')));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(c.gridOpen, isTrue, reason: 'still holding');
    await g.up();
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
      // The card zooms in first; the tab (and its header) shows when that ends.
      await tester.pump(); // the zoom starts
      await tester.pump(const Duration(milliseconds: 250)); // and ends
      await tester.pump();
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

  testWidgets('the grid opens scrolled to the current tab', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    for (var i = 0; i < 40; i++) {
      c.open(CounterTab('t$i'), foreground: false, index: c.length);
    }
    c.select(c.tabs[36]);
    await tester.pumpWidget(app(c));
    c.gridOpen = true;
    await tester.pumpAndSettle();
    final card = find.text(c.tabs[36].title);
    expect(card, findsWidgets);
    final y = tester.getCenter(card.first).dy;
    expect(y, inInclusiveRange(0, tester.view.physicalSize.height / tester.view.devicePixelRatio));
  });

  testWidgets('swiping: a haptic at the closing point, the card above its neighbours, the rest slide in', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    for (final id in ['a', 'b', 'c']) {
      c.open(CounterTab(id), foreground: false, index: c.length);
    }
    c.gridOpen = true;
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    final cStart = tester.getTopLeft(find.text('Tab c'));

    final drag = await tester.startGesture(tester.getCenter(find.text('Tab a')));
    await drag.moveBy(const Offset(30, 0));
    await tester.pump();
    // The dragged card is painted last (on top of the card to its right).
    final stack = tester.widget<Stack>(find.ancestor(of: find.text('Tab a'), matching: find.byType(Stack)).first);
    expect((stack.children.last.key! as ValueKey).value, 'a');
    expect(haptics, isEmpty);
    await drag.moveBy(const Offset(300, 0));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.mediumImpact'], reason: 'past the closing point');
    await drag.up();
    await tester.pump(); // the fly-off starts
    await tester.pump(const Duration(milliseconds: 300)); // and ends: the tab closes
    await tester.pump();
    expect(c.tabs.map((t) => t.id), ['b', 'c']);

    // c moves to b's old spot, animated.
    await tester.pump(const Duration(milliseconds: 100));
    final cMid = tester.getTopLeft(find.text('Tab c'));
    await tester.pumpAndSettle();
    final cEnd = tester.getTopLeft(find.text('Tab c'));
    expect(cEnd, isNot(cStart));
    expect(cMid, isNot(cEnd), reason: 'still on its way after 100 ms');
  });

  testWidgets('zooming moves only the tab picture: the cards stay where they are', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'));
    await tester.pumpWidget(app(c));
    c.gridOpen = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid-zoom
    final mid = tester.getTopLeft(find.text('Tab a'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Tab a')), mid);
  });

  testWidgets('a long press and drag moves a card; a long press alone opens its sheet', (tester) async {
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'))
      ..open(CounterTab('c'))
      ..gridOpen = true;
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect([for (final t in c.tabs) t.id], ['a', 'b', 'c']);

    // Hold a, drag it onto c (the next row).
    final gesture = await tester.startGesture(tester.getCenter(find.text('Tab a')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final to = tester.getCenter(find.text('Tab c'));
    final from = tester.getCenter(find.text('Tab a'));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect([for (final t in c.tabs) t.id], ['b', 'c', 'a']);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.longPress(find.text('Tab b'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect([for (final t in c.tabs) t.id], ['b', 'c', 'a']);
  });

  testWidgets('a long press and drag moves a tab along the strip', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = TabSwitcherController();
    addTearDown(c.dispose);
    c
      ..open(CounterTab('a'))
      ..open(CounterTab('b'))
      ..open(CounterTab('c'));
    await tester.pumpWidget(app(c));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Tab c')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final from = tester.getCenter(find.text('Tab c'));
    final to = tester.getCenter(find.text('Tab a'));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.tabs.first.id, 'c');
    expect(find.byType(BottomSheet), findsNothing);
  });
}
