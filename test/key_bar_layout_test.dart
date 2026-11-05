import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/keys/key_bar_layout.dart';

void main() {
  test('rows, alternates and escapes', () {
    final rows = parseKeyBar('ESC (,(),((  \\,,\\\\ \\ \n\nTAB a,b,');
    expect(rows, [
      [
        const BarKey('ESC'),
        const BarKey('(', ['()', '((']),
        const BarKey(',', ['\\']),
        const BarKey(' '),
      ],
      [
        const BarKey('TAB'),
        const BarKey('a', ['b']),
      ],
    ]);
  });

  test('a lone comma is a key, not a separator', () {
    expect(parseKeyBar(', ;'), [
      [const BarKey(','), const BarKey(';')],
    ]);
  });

  test('format round-trips', () {
    for (final p in [...terminalPresets, ...editorPresets]) {
      final rows = parseKeyBar(p.layout);
      expect(parseKeyBar(formatKeyBar(rows)), rows, reason: p.id);
    }
  });

  test('presets parse to what they mean', () {
    final t = parseKeyBar(terminalPresets[1].layout);
    expect(t.length, 2);
    expect(t[0][1], const BarKey('/', ['\\', '|']));
    expect(t[1].map((k) => k.main), ['TAB', 'CTRL', 'ALT', 'LEFT', 'DOWN', 'RIGHT', 'PGDN']);
    final e = parseKeyBar(editorPresets[0].layout);
    expect(e.single.last, const BarKey(','));
    expect(e.single, contains(const BarKey('\\')));
    expect(e.single, contains(const BarKey(r'$', [r'${}'])));
    final e2 = parseKeyBar(editorPresets[1].layout);
    expect(e2[0][2], const BarKey('(', ['()', '((', ')']));
    expect(e2[0][7], const BarKey('"', ["'", '`', '""']));
    for (final p in [...terminalPresets, ...editorPresets]) {
      for (final k in parseKeyBar(p.layout).expand((r) => r)) {
        expect(k.main.trim(), isNotEmpty, reason: p.id);
      }
    }
  });

  test('bracket pairs put the cursor inside', () {
    expect(isBracketPair('()'), isTrue);
    expect(isBracketPair(r'${}'), isTrue);
    expect(isBracketPair('""'), isTrue);
    expect(isBracketPair('(('), isFalse);
    expect(isBracketPair('->'), isFalse);
    expect(isBracketPair(')'), isFalse);
  });

  test('custom layout falls back to the first preset when empty', () {
    expect(keyBarLayout(KeyBarFor.terminal, 'custom', '  '), parseKeyBar(terminalPresets.first.layout));
    expect(keyBarLayout(KeyBarFor.editor, 'custom', 'TAB x'), [
      [const BarKey('TAB'), const BarKey('x')],
    ]);
    expect(keyBarLayout(KeyBarFor.editor, 'two_rows', null).length, 2);
  });
}
