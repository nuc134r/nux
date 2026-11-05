/// Line diffs (Myers' algorithm), for "what changed on the server" and later git.
library;

enum DiffKind { same, removed, added }

class DiffLine {
  const DiffLine(this.kind, this.text, {this.oldLine, this.newLine});

  final DiffKind kind;
  final String text;

  /// 1-based line numbers in the old / new text (null where the line is not in it).
  final int? oldLine;
  final int? newLine;

  @override
  String toString() =>
      '${switch (kind) {
        DiffKind.same => ' ',
        DiffKind.removed => '-',
        DiffKind.added => '+',
      }}$text';
}

/// Every line of [oldText] and [newText] in order, marked same / removed / added.
List<DiffLine> diffLines(String oldText, String newText) {
  final a = oldText.split('\n'), b = newText.split('\n');
  // Common start and end are not diffed (most edits are small).
  var start = 0;
  while (start < a.length && start < b.length && a[start] == b[start]) {
    start++;
  }
  var endA = a.length, endB = b.length;
  while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }
  final out = <DiffLine>[for (var i = 0; i < start; i++) DiffLine(DiffKind.same, a[i], oldLine: i + 1, newLine: i + 1)];
  for (final (kind, i, j) in _myers(a.sublist(start, endA), b.sublist(start, endB))) {
    out.add(switch (kind) {
      DiffKind.same => DiffLine(kind, a[start + i], oldLine: start + i + 1, newLine: start + j + 1),
      DiffKind.removed => DiffLine(kind, a[start + i], oldLine: start + i + 1),
      DiffKind.added => DiffLine(kind, b[start + j], newLine: start + j + 1),
    });
  }
  for (var k = 0; k < a.length - endA; k++) {
    out.add(DiffLine(DiffKind.same, a[endA + k], oldLine: endA + k + 1, newLine: endB + k + 1));
  }
  return out;
}

/// The edit script from [a] to [b]: (kind, index in a, index in b).
List<(DiffKind, int, int)> _myers(List<String> a, List<String> b) {
  final n = a.length, m = b.length, max = n + m;
  if (n == 0) return [for (var j = 0; j < m; j++) (DiffKind.added, 0, j)];
  if (m == 0) return [for (var i = 0; i < n; i++) (DiffKind.removed, i, 0)];
  final offset = max;
  var v = List<int>.filled(2 * max + 2, 0);
  final trace = <List<int>>[];
  outer:
  for (var d = 0; d <= max; d++) {
    trace.add(List.of(v));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
          ? v[offset + k + 1]
          : v[offset + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a[x] == b[y]) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) break outer;
    }
  }
  // Walk back through the saved frontiers.
  final script = <(DiffKind, int, int)>[];
  var x = n, y = m;
  for (var d = trace.length - 1; d >= 0; d--) {
    v = trace[d];
    final k = x - y;
    final prevK = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) ? k + 1 : k - 1;
    final prevX = v[offset + prevK];
    final prevY = prevX - prevK;
    while (x > prevX && y > prevY) {
      x--;
      y--;
      script.add((DiffKind.same, x, y));
    }
    if (d > 0) {
      if (x == prevX) {
        y--;
        script.add((DiffKind.added, x, y));
      } else {
        x--;
        script.add((DiffKind.removed, x, y));
      }
    }
  }
  return script.reversed.toList();
}

/// The changed parts with [context] unchanged lines around each; runs of unchanged lines between them
/// become null (a "…" separator).
List<DiffLine?> diffHunks(List<DiffLine> lines, {int context = 3}) {
  final keep = List<bool>.filled(lines.length, false);
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].kind == DiffKind.same) continue;
    for (var j = (i - context).clamp(0, lines.length); j <= (i + context).clamp(0, lines.length - 1); j++) {
      keep[j] = true;
    }
  }
  final out = <DiffLine?>[];
  for (var i = 0; i < lines.length; i++) {
    if (keep[i]) {
      out.add(lines[i]);
    } else if (out.isNotEmpty && out.last != null) {
      out.add(null);
    }
  }
  if (out.isNotEmpty && out.last == null) out.removeLast();
  return out;
}

/// One row of a side-by-side diff: the old line on the left, the new on the right (either may be missing).
typedef SideBySideRow = (DiffLine? old, DiffLine? now);

/// [lines] (as from [diffHunks], null between hunks) as side-by-side rows: unchanged lines on both sides,
/// each run of removed lines next to the added lines that follow it.
List<SideBySideRow?> sideBySide(List<DiffLine?> lines) {
  final out = <SideBySideRow?>[];
  final removed = <DiffLine>[], added = <DiffLine>[];
  void flush() {
    for (var i = 0; i < removed.length || i < added.length; i++) {
      out.add((i < removed.length ? removed[i] : null, i < added.length ? added[i] : null));
    }
    removed.clear();
    added.clear();
  }

  for (final l in lines) {
    if (l == null) {
      flush();
      out.add(null);
    } else if (l.kind == DiffKind.removed) {
      if (added.isNotEmpty) flush();
      removed.add(l);
    } else if (l.kind == DiffKind.added) {
      added.add(l);
    } else {
      flush();
      out.add((l, l));
    }
  }
  flush();
  return out;
}
