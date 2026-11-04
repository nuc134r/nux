import 'package:flutter_test/flutter_test.dart';
import 'package:tab_switcher/tab_switcher.dart';

import 'helpers.dart';

void main() {
  late TabSwitcherController c;
  setUp(() => c = TabSwitcherController(keepAlive: 1));
  tearDown(() => c.dispose());

  List<String> ids() => c.tabs.map((t) => t.id).toList();

  test('opens next to the current tab and selects it', () {
    c.open(CounterTab('a'));
    c.open(CounterTab('b'));
    c.select(c.tabs.first);
    c.open(CounterTab('c'));
    expect(ids(), ['a', 'c', 'b']);
    expect(c.current?.id, 'c');
    expect(c.gridOpen, isFalse);
    c.open(CounterTab('d'), foreground: false);
    expect(c.current?.id, 'c');
  });

  test('opening an open id selects it and disposes the duplicate', () {
    final a = CounterTab('a'), dup = CounterTab('a');
    c.open(a);
    c.open(CounterTab('b'));
    c.open(dup);
    expect(c.length, 2);
    expect(c.current, a);
    expect(dup.disposed, isTrue);
  });

  test('closing selects the previously used tab and can be undone', () async {
    for (final id in ['a', 'b', 'c']) {
      c.open(CounterTab(id));
    }
    c.select(c.tabs[0]); // a
    c.select(c.tabs[2]); // c
    final c2 = c.current!;
    expect(await c.close(c2), isTrue);
    expect(c.current?.id, 'a');
    expect(c.reopenClosed(), c2);
    expect(ids(), ['a', 'b', 'c']);
    expect(c.current?.id, 'c');
  });

  test('closing the last tab opens the grid', () async {
    c.open(CounterTab('a'));
    await c.close(c.tabs.single);
    expect(c.current, isNull);
    expect(c.gridOpen, isTrue);
  });

  test('live set is the current tab plus keepAlive recent ones', () {
    for (final id in ['a', 'b', 'c']) {
      c.open(CounterTab(id));
    }
    expect(c.liveIds, {'c', 'b'});
    c.select(c.tabs[0]);
    expect(c.liveIds, {'a', 'c'});
  });

  test('pinned tabs stay first and survive close others', () async {
    for (final id in ['a', 'b', 'c']) {
      c.open(CounterTab(id));
    }
    c.setPinned(c.tabs[2], true);
    expect(ids(), ['c', 'a', 'b']);
    c.open(CounterTab('d')); // current is c (pinned): new tabs go after the pinned section
    expect(ids(), ['c', 'd', 'a', 'b']);
    await c.closeOthers(c.tabs[1]);
    expect(ids(), ['c', 'd']);
    c.move(c.tabs[1], 0);
    expect(ids(), ['c', 'd'], reason: 'unpinned tabs cannot move before pinned ones');
  });

  test('unsaved changes ask before closing', () async {
    final a = CounterTab('a', unsaved: true);
    c.open(a);
    var asked = 0;
    c.confirmClose = (tab) async {
      asked++;
      return false;
    };
    expect(await c.close(a), isFalse);
    expect(c.length, 1);
    expect(await c.close(a, force: true), isTrue);
    expect(asked, 1);
  });

  test('closed tabs beyond the undo depth are disposed', () async {
    final small = TabSwitcherController(undoDepth: 1);
    addTearDown(small.dispose);
    final a = CounterTab('a'), b = CounterTab('b');
    small
      ..open(a)
      ..open(b);
    await small.close(a);
    expect(a.disposed, isFalse);
    await small.close(b);
    expect(a.disposed, isTrue);
    expect(b.disposed, isFalse);
  });

  test('title changes notify', () {
    final a = CounterTab('a');
    c.open(a);
    var n = 0;
    c.addListener(() => n++);
    a.notifyListeners();
    expect(n, 1);
  });

  test('detach takes a whole set out alive; attach brings it back as it was', () {
    final a = CounterTab('a'), b = CounterTab('b');
    c.open(a);
    c.open(b);
    c.setPinned(b, true);
    c.select(a);
    final set = c.detach();
    expect(c.isEmpty, isTrue);
    expect(a.disposed || b.disposed, isFalse);

    c.open(CounterTab('x'));
    c.attach(set);
    expect(ids(), ['b', 'a']);
    expect(c.current, a);
    expect(c.isPinned(b), isTrue);
    var notified = 0;
    c.addListener(() => notified++);
    a.notifyListeners();
    expect(notified, 1, reason: 'attached tabs are listened to again');
  });
}
