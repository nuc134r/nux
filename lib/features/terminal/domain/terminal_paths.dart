/// File paths in terminal output (`ls`, `grep -n`, compiler errors), so they can be opened in an editor tab.
library;

import 'package:nux_backend/nux_backend.dart' show posix;

/// A path and, for `file:12` or `file:12:5`, the line.
typedef TerminalPath = ({String path, int? line});

/// Characters that end a word when a long press selects one: whitespace, quotes, brackets and shell
/// punctuation, but not `/ . : ~ -`, so a whole path (with its `:line`) is selected at once.
const terminalWordBoundaries = ' \t"\'`()[]{}<>|;,&=';

final _pathRe = RegExp(r'^(~|\.{1,2})?/?[\w@+\-.~/]*[\w@+\-~/](:\d+)?(:\d+)?$');

/// [text] as a file path, or null when it does not look like one (a URL, an option, a plain word).
TerminalPath? parseTerminalPath(String text) {
  var t = text.trim();
  // Trailing punctuation from a sentence or a list.
  while (t.isNotEmpty && '.,;:)'.contains(t[t.length - 1]) && !RegExp(r':\d+$').hasMatch(t)) {
    t = t.substring(0, t.length - 1);
  }
  if (t.isEmpty || t.contains('://') || t.startsWith('-') || !_pathRe.hasMatch(t)) return null;
  int? line;
  final m = RegExp(r'^(.*?)(?::(\d+))?(?::\d+)?$').firstMatch(t)!;
  final path = m.group(1)!;
  if (m.group(2) != null) line = int.parse(m.group(2)!);
  // A path has a folder in it or a file extension (`notes.md`), not just a word.
  final name = posix.basename(path);
  final hasExtension = RegExp(r'^[^.].*\.[A-Za-z0-9]*[A-Za-z][A-Za-z0-9]*$').hasMatch(name) || name.startsWith('.') && name.length > 1;
  if (!path.contains('/') && !hasExtension) return null;
  if (path == '/' || path.endsWith('/')) return null;
  return (path: path, line: line);
}

/// The folder in an OSC 7 report (`file://host/path`, percent-encoded), or a plain absolute path.
String? pwdPath(String pwd) {
  if (pwd.startsWith('/')) return pwd;
  final uri = Uri.tryParse(pwd);
  if (uri == null || uri.scheme != 'file' || uri.path.isEmpty) return null;
  return Uri.decodeComponent(uri.path);
}

/// [path] made absolute against the shell's folder [cwd] and [home]; null when it is relative and the
/// folder is not known.
String? resolveTerminalPath(String path, {String? cwd, String? home}) {
  if (path.startsWith('/')) return posix.normalize(path);
  if (path == '~' || path.startsWith('~/')) {
    return home == null ? null : posix.normalize(posix.join(home, path.substring(path == '~' ? 1 : 2)));
  }
  return cwd == null ? null : posix.normalize(posix.join(cwd, path));
}
