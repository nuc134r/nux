import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/flterm.dart' hide Key;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long press selects the word under the finger, without a drag', (tester) async {
    final c = TerminalController();
    var grid = (0, 0);
    c.onResize = (cols, rows) => grid = (cols, rows);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(
            controller: c,
            gestureSettings: const TerminalGestureSettings(wordBoundaries: ' '),
          ),
        ),
      ),
    );
    c.write(Uint8List.fromList(utf8.encode('${'\r\n' * 20}hello world')));
    await tester.pump();
    // The middle of "world" on the first row.
    final rect = tester.getRect(find.byType(TerminalView));
    final cell = Size(rect.width / grid.$1, rect.height / grid.$2);
    // "world" on row 21; held past the long-press delay, not moved.
    final g = await tester.startGesture(rect.topLeft + Offset(cell.width * 8.5, cell.height * 20.5));
    await tester.pump(const Duration(milliseconds: 700));
    expect(c.selectedText().trim(), 'world', reason: 'selected while the finger is still down');
    await g.up();
    await tester.pumpAndSettle();
    expect(c.selectedText().trim(), 'world');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a paste keeps one Enter per line (Windows line endings too), bracketed when asked', (tester) async {
    final c = TerminalController();
    final out = <int>[];
    c.onOutput = out.addAll;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TerminalView(controller: c))));
    c.paste('echo a\r\necho b\n');
    expect(utf8.decode(out), 'echo a\recho b\r');
    out.clear();
    c.write(Uint8List.fromList(utf8.encode('\x1b[?2004h')));
    c.paste('echo a\r\necho b');
    expect(utf8.decode(out), '\x1b[200~echo a\necho b\x1b[201~');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

}
