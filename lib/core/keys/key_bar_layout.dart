/// The extra keys above the keyboard (terminal and editor): rows of keys, each with optional long-press
/// alternates, written as text so presets and custom layouts are the same thing.
///
/// One row per line; keys separated by spaces; a key's long-press alternates follow it after commas
/// (`(,(),((` is `(` with `()` and `((`). A backslash takes the next character literally (`\,` `\\` `\ `).
/// Upper-case names are special keys: [specialKeys].
library;

class BarKey {
  const BarKey(this.main, [this.alternates = const []]);

  /// A special key name or text to type.
  final String main;

  /// Offered on long press.
  final List<String> alternates;

  @override
  bool operator ==(Object other) =>
      other is BarKey && other.main == main && other.alternates.join('\u0000') == alternates.join('\u0000');

  @override
  int get hashCode => Object.hash(main, alternates.join('\u0000'));

  @override
  String toString() => [main, ...alternates].join(',');
}

/// Special keys: their labels. The terminal and the editor each show the ones they can do.
const specialKeys = {
  'ESC': 'Esc',
  'TAB': 'Tab',
  'STAB': '⇤',
  'CTRL': 'Ctrl',
  'ALT': 'Alt',
  'LEFT': '←',
  'UP': '↑',
  'DOWN': '↓',
  'RIGHT': '→',
  'HOME': 'Home',
  'END': 'End',
  'PGUP': 'PgUp',
  'PGDN': 'PgDn',
  'INS': 'Ins',
  'DEL': 'Del',
  'BKSP': '⌫',
  'ENTER': '⏎',
  'SPACE': '␣',
  'UNDO': '↶',
  'REDO': '↷',
  'F1': 'F1',
  'F2': 'F2',
  'F3': 'F3',
  'F4': 'F4',
  'F5': 'F5',
  'F6': 'F6',
  'F7': 'F7',
  'F8': 'F8',
  'F9': 'F9',
  'F10': 'F10',
  'F11': 'F11',
  'F12': 'F12',
};

bool isSpecialKey(String token) => specialKeys.containsKey(token);

/// What a key shows.
String keyLabel(String token) => specialKeys[token] ?? token;

/// Keys that type again and again while held (instead of offering alternates).
bool keyRepeats(String token) =>
    !isSpecialKey(token) ||
    const {'LEFT', 'UP', 'DOWN', 'RIGHT', 'PGUP', 'PGDN', 'DEL', 'BKSP', 'SPACE', 'UNDO', 'REDO'}.contains(token);

/// Ctrl and Alt: tap for the next key, long-press to lock.
bool isModifierKey(String token) => token == 'CTRL' || token == 'ALT';

List<List<BarKey>> parseKeyBar(String text) {
  final rows = <List<BarKey>>[];
  for (final line in text.split('\n')) {
    final keys = <BarKey>[];
    final parts = <String>[];
    final part = StringBuffer();
    var any = false;
    void endPart() {
      parts.add('$part');
      part.clear();
    }

    void endKey() {
      if (!any) return;
      endPart();
      final list = parts.where((p) => p.isNotEmpty).toList();
      if (list.isNotEmpty) keys.add(BarKey(list.first, list.sublist(1)));
      parts.clear();
      any = false;
    }

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '\\' && i + 1 < line.length) {
        part.write(line[++i]);
        any = true;
      } else if (c == ' ' || c == '\t' || c == '\r') {
        endKey();
      } else if (c == ',' && any) {
        endPart();
      } else {
        part.write(c);
        any = true;
      }
    }
    endKey();
    if (keys.isNotEmpty) rows.add(keys);
  }
  return rows;
}

/// Writes a key back in the layout syntax (escaping what needs it).
String formatKey(BarKey key) => [key.main, ...key.alternates].map(_escape).join(',');

String formatKeyBar(List<List<BarKey>> rows) => rows.map((r) => r.map(formatKey).join(' ')).join('\n');

String _escape(String s) => s.replaceAllMapped(RegExp(r'[\\, \t]'), (m) => '\\${m[0]}');

/// Text that is an opening and closing pair (`()`, `${}`, `""`): the cursor goes before the closing one.
bool isBracketPair(String text) {
  if (text.length < 2) return false;
  const pairs = {')': '(', ']': '[', '}': '{', '>': '<', '"': '"', "'": "'", '`': '`'};
  final open = pairs[text[text.length - 1]];
  return open != null && text.substring(0, text.length - 1).contains(open);
}

enum KeyBarFor { terminal, editor }

class KeyBarPreset {
  const KeyBarPreset(this.id, this.layout);

  final String id;
  final String layout;
}

const terminalPresets = [
  KeyBarPreset(
    'one_row',
    r'ESC TAB CTRL ALT LEFT UP DOWN RIGHT |,|| ~ /,\\ -,_ $,${},$() *,** &,&&,2>&1 >,>> < HOME END PGUP PGDN',
  ),
  KeyBarPreset('two_rows', 'ESC /,\\\\,| -,_,= HOME UP END PGUP\nTAB CTRL ALT LEFT DOWN RIGHT PGDN'),
  KeyBarPreset(
    'two_rows_symbols',
    'ESC |,|| ~ /,\\\\ -,_ \$,\${},\$() *,** &,&&,2>&1 >,>> <,<<\nTAB CTRL ALT LEFT UP DOWN RIGHT HOME,PGUP END,PGDN',
  ),
];

const editorPresets = [
  KeyBarPreset(
    'one_row',
    'TAB STAB LEFT UP DOWN RIGHT HOME END UNDO REDO {,{} } (,() ) [,[] ] <,<> > ; : =,==,=> ","" \',\'\' `,`` / \\\\ | &,&& !,!= ? -,-> _ + * # \$,\${} % @ ~ ^ . \\,',
  ),
  KeyBarPreset(
    'two_rows',
    'TAB {,{},} (,(),((,) [,[],] <,<>,> ;,: =,==,=>,!= ",\',`,"" /,\\\\,|\nSTAB LEFT UP DOWN RIGHT HOME END UNDO REDO',
  ),
  KeyBarPreset(
    'two_rows_symbols',
    'TAB {,{} } (,(),(( ) [,[] ] ;,: =,==,=> ",""\nSTAB LEFT RIGHT \',\'\' `,`` /,// \\\\ |,|| &,&& !,!= -,->,_ +,+= *,** #,\$,\${} UNDO REDO',
  ),
];

List<KeyBarPreset> keyBarPresets(KeyBarFor kind) => kind == KeyBarFor.terminal ? terminalPresets : editorPresets;

/// The layout for a stored setting: a preset id, or `custom` with [custom] text.
List<List<BarKey>> keyBarLayout(KeyBarFor kind, String? presetId, String? custom) {
  final presets = keyBarPresets(kind);
  if (presetId == 'custom' && custom != null) {
    final rows = parseKeyBar(custom);
    if (rows.isNotEmpty) return rows;
  }
  final preset = presets.firstWhere((p) => p.id == presetId, orElse: () => presets.first);
  return parseKeyBar(preset.layout);
}
