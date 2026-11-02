/// Quotes [value] as one POSIX shell word, so it can be inserted into a command line safely.
///
/// Plain words stay as they are (`main.dart` → `main.dart`); anything else is wrapped in single
/// quotes with embedded quotes escaped (`it's` → `'it'"'"'s'`).
String shellQuote(String value) {
  if (value.isEmpty) return "''";
  if (_safe.hasMatch(value)) return value;
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

/// Joins [words] into a command line, quoting each one.
String shellJoin(Iterable<String> words) => words.map(shellQuote).join(' ');

final _safe = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');
