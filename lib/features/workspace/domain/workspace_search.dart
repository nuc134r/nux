import 'package:nux_backend/nux_backend.dart';

/// Lists the project's files, relative to [root]: git's view (tracked and untracked, ignored ones left
/// out) in a repository, every file but `.git` and `node_modules` elsewhere.
String listFilesCommand(String root) =>
    'cd ${shellQuote(root)} && { if git rev-parse --is-inside-work-tree >/dev/null 2>&1; '
    'then git ls-files -co --exclude-standard; '
    "else find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' | sed 's|^\\./||'; fi; } | head -n 50000";

List<String> parseFileList(CommandResult result) => [
  for (final l in result.stdout.split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

/// Finds [query] (plain text) in the project's files: ripgrep when the host has it (it skips ignored and
/// binary files), grep otherwise. Case-insensitive unless the query has a capital letter.
String searchCommand(String root, String query) {
  final ignoreCase = query == query.toLowerCase();
  final q = shellQuote(query);
  return 'cd ${shellQuote(root)} && { if command -v rg >/dev/null 2>&1; '
      'then rg -n --no-heading --color never --null -F ${ignoreCase ? '-i ' : ''}-e $q .; '
      'else grep -rnIZF ${ignoreCase ? '-i ' : ''}--exclude-dir=.git --exclude-dir=node_modules -e $q .; fi; } '
      '| head -n 2000';
}

class SearchHit {
  const SearchHit({required this.path, required this.line, required this.text});

  /// Relative to the workspace folder.
  final String path;

  /// 1-based.
  final int line;
  final String text;
}

/// Reads [searchCommand]'s output (`path\0line:text`, one per line).
List<SearchHit> parseSearch(CommandResult result) {
  final hits = <SearchHit>[];
  for (final l in result.stdout.split('\n')) {
    final nul = l.indexOf('\x00');
    if (nul < 0) continue;
    var path = l.substring(0, nul);
    if (path.startsWith('./')) path = path.substring(2);
    final rest = l.substring(nul + 1);
    final colon = rest.indexOf(':');
    final line = colon < 0 ? null : int.tryParse(rest.substring(0, colon));
    if (line == null) continue;
    var text = rest.substring(colon + 1).trimRight();
    if (text.length > 300) text = '${text.substring(0, 300)}…';
    hits.add(SearchHit(path: path, line: line, text: text));
  }
  return hits;
}

/// How well [query] matches [path] as a fuzzy file name (its letters in order); null when it does not.
/// Matches in the file name, at word starts and in runs score higher; shorter paths win ties.
int? fuzzyScore(String query, String path) {
  final q = query.toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) return 0;
  final p = path.toLowerCase();
  final nameStart = path.lastIndexOf('/') + 1;

  int? scoreFrom(int start) {
    var score = 0, qi = 0, last = -2;
    for (var i = start; i < p.length && qi < q.length; i++) {
      if (p[i] != q[qi]) continue;
      score += 10;
      if (i == last + 1) score += 15;
      final prev = i == 0 ? '/' : path[i - 1];
      final wordStart = '/_-. '.contains(prev) || (path[i] != p[i] && prev == prev.toLowerCase());
      if (wordStart) score += 20;
      if (i >= nameStart) score += 10;
      last = i;
      qi++;
    }
    return qi == q.length ? score : null;
  }

  // Prefer a match inside the file name; otherwise anywhere in the path.
  final inName = scoreFrom(nameStart);
  final best = inName != null ? inName + 50 : scoreFrom(0);
  return best == null ? null : best * 100 - path.length;
}

/// [paths] that match [query], best first (at most [limit]).
List<String> fuzzyFilter(String query, Iterable<String> paths, {int limit = 100}) {
  if (query.trim().isEmpty) return paths.take(limit).toList();
  final scored = <(int, String)>[];
  for (final p in paths) {
    final s = fuzzyScore(query, p);
    if (s != null) scored.add((s, p));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, p) in scored.take(limit)) p];
}
