import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/keys/key_bar_layout.dart';
import 'package:nux/core/widgets/key_bar.dart';

void main() {
  Future<List<String>> pumpBar(WidgetTester tester, String layout, {void Function(String)? onLock}) async {
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: KeyBar(rows: parseKeyBar(layout), onKey: typed.add, onLock: onLock),
          ),
        ),
      ),
    );
    return typed;
  }

  testWidgets('tap types; two rows fill the width', (tester) async {
    final typed = await pumpBar(tester, 'ESC a\nTAB b');
    await tester.tap(find.text('a'));
    await tester.tap(find.text('Esc'));
    expect(typed, ['a', 'ESC']);
    // Two keys share the 800 px row: each is wide.
    expect(
      tester.getSize(find.ancestor(of: find.text('a'), matching: find.byType(Expanded)).first).width,
      greaterThan(300),
    );
  });

  testWidgets('holding an arrow repeats it until let go', (tester) async {
    final typed = await pumpBar(tester, 'LEFT');
    final g = await tester.startGesture(tester.getCenter(find.text('←')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(typed, isEmpty);
    await tester.pump(const Duration(milliseconds: 100)); // the hold: types once and starts repeating
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    final count = typed.length;
    expect(count, greaterThan(4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(typed.length, count, reason: 'stopped on release');
    expect(typed.toSet(), {'LEFT'});
  });

  testWidgets('holding a key with alternates offers them; slide and let go to pick', (tester) async {
    final typed = await pumpBar(tester, '(,(),((');
    final g = await tester.startGesture(tester.getCenter(find.text('(')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('()'), findsOneWidget);
    expect(find.text('(('), findsOneWidget);
    // The first alternate is chosen until the finger moves; slide onto (( and let go.
    await g.moveTo(tester.getCenter(find.text('((')));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(typed, ['((']);
    expect(find.text('()'), findsNothing, reason: 'the popup closed');

    final g2 = await tester.startGesture(tester.getCenter(find.text('(')));
    await tester.pump(const Duration(milliseconds: 450));
    await g2.up();
    expect(typed.last, '()');
  });

  testWidgets('holding Ctrl locks it', (tester) async {
    final locked = <String>[];
    final typed = await pumpBar(tester, 'CTRL', onLock: locked.add);
    final g = await tester.startGesture(tester.getCenter(find.text('Ctrl')));
    await tester.pump(const Duration(milliseconds: 450));
    await g.up();
    expect(locked, ['CTRL']);
    expect(typed, isEmpty);
  });

  testWidgets('a drag on a scrolling row does not type', (tester) async {
    final typed = await pumpBar(tester, List.generate(40, (i) => 'k$i').join(' '));
    await tester.drag(find.text('k3'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(typed, isEmpty);
  });
}
