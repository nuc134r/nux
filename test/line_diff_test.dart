import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/viewer/domain/line_diff.dart';

/// Applies a diff: the "same" and "added" lines must give the new text, "same" and "removed" the old.
void check(String a, String b) {
  final d = diffLines(a, b);
  expect(d.where((l) => l.kind != DiffKind.added).map((l) => l.text).join('\n'), a);
  expect(d.where((l) => l.kind != DiffKind.removed).map((l) => l.text).join('\n'), b);
}

void main() {
  test('a small edit is a small diff', () {
    final d = diffLines('a\nb\nc\nd', 'a\nB\nc\nd\ne');
    expect(d.map((l) => '$l').toList(), [' a', '-b', '+B', ' c', ' d', '+e']);
    expect(d[2].newLine, 2);
    expect(d[1].oldLine, 2);
  });

  test('round-trips on random edits', () {
    final r = Random(7);
    for (var t = 0; t < 200; t++) {
      List<String> lines() => [for (var i = 0; i < r.nextInt(30); i++) String.fromCharCode(97 + r.nextInt(4))];
      check(lines().join('\n'), lines().join('\n'));
    }
    check('', 'x');
    check('x', '');
  });

  test('hunks keep context and fold the rest', () {
    final a = List.generate(20, (i) => 'l$i').join('\n');
    final b = a.replaceFirst('l10', 'L10');
    final h = diffHunks(diffLines(a, b), context: 2);
    expect(h.map((l) => l?.toString() ?? '…').toList(), [' l8', ' l9', '-l10', '+L10', ' l11', ' l12']);
  });

  test('side by side pairs each run of removed lines with the added lines after it', () {
    final rows = sideBySide(diffLines('a\nb\nc\nd', 'a\nB\nC\nX\nd'));
    String side(DiffLine? l) => l?.toString() ?? '_';
    expect(rows.map((r) => '${side(r!.$1)}|${side(r.$2)}').toList(), [
      ' a| a',
      '-b|+B',
      '-c|+C',
      '_|+X',
      ' d| d',
    ]);
    expect(sideBySide([null]), [null]);
  });
}
