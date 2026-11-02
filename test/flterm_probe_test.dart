import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/flterm.dart' as ft;
import 'package:flterm/flterm.dart' hide Key;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('probe', (tester) async {
    final c = TerminalController();
    final out = <int>[];
    c.onOutput = out.addAll;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TerminalView(controller: c))));
    c.write(Uint8List.fromList(utf8.encode('hello \x1b[31mred\x1b[0m\r\n')));
    await tester.pump();
    c.sendKey(ft.Key.arrowUp);
    c.sendText('x');
    c.selectAll();
    // ignore: avoid_print
    print('sel=${c.selectedText().trim()} out=$out snap=${c.snapshot().length}');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
