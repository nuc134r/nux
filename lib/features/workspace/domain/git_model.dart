import '../../viewer/domain/line_diff.dart';

/// Field and record separators in git `--format` output (unlikely in messages).
const gitFieldSep = '\x1f';
const gitRecordSep = '\x1e';

class GitCommit {
  const GitCommit({
    required this.hash,
    required this.author,
    required this.email,
    required this.time,
    required this.parents,
    required this.subject,
    this.refs = const [],
  });

  final String hash;
  final String author;
  final String email;
  final DateTime time;
  final List<String> parents;
  final String subject;

  /// Branch and tag names pointing at it (`HEAD -> main`, `origin/main`, `tag: v1`).
  final List<String> refs;

  String get short => hash.substring(0, hash.length < 7 ? hash.length : 7);
  bool get isMerge => parents.length > 1;
}

/// The `--format` that [parseLog] reads.
const gitLogFormat = '%H%x1f%an%x1f%ae%x1f%at%x1f%P%x1f%D%x1f%s%x1e';

List<GitCommit> parseLog(String out) => [
  for (final record in out.split(gitRecordSep))
    if (record.trim().isNotEmpty) _commit(record.trim()),
];

GitCommit _commit(String record) {
  final f = record.split(gitFieldSep);
  return GitCommit(
    hash: f[0],
    author: f[1],
    email: f[2],
    time: DateTime.fromMillisecondsSinceEpoch((int.tryParse(f[3]) ?? 0) * 1000),
    parents: [for (final p in f[4].split(' ')) if (p.isNotEmpty) p],
    refs: [for (final r in f[5].split(', ')) if (r.trim().isNotEmpty) r.trim()],
    subject: f.length > 6 ? f.sublist(6).join(gitFieldSep) : '',
  );
}

/// Lanes for a commit graph: which column each commit sits in and which columns pass through its row.
class GraphRow {
  const GraphRow(this.column, this.lanes, this.merges);

  /// The commit's own column.
  final int column;

  /// Columns that continue through this row (including the commit's).
  final int lanes;

  /// Columns its other parents start in (drawn as lines from the commit).
  final List<int> merges;
}

/// A simple lane layout for [commits] in log order (newest first).
List<GraphRow> graphLanes(List<GitCommit> commits) {
  final lanes = <String?>[]; // the hash each lane is waiting for
  final rows = <GraphRow>[];
  for (final c in commits) {
    var column = lanes.indexOf(c.hash);
    if (column < 0) {
      column = lanes.indexOf(null);
      if (column < 0) {
        lanes.add(null);
        column = lanes.length - 1;
      }
    }
    // Other lanes waiting for this commit end here.
    for (var i = 0; i < lanes.length; i++) {
      if (i != column && lanes[i] == c.hash) lanes[i] = null;
    }
    final merges = <int>[];
    lanes[column] = c.parents.isEmpty ? null : c.parents.first;
    for (final p in c.parents.skip(1)) {
      var lane = lanes.indexOf(p);
      if (lane < 0) {
        lane = lanes.indexOf(null);
        if (lane < 0) {
          lanes.add(p);
          lane = lanes.length - 1;
        } else {
          lanes[lane] = p;
        }
      }
      merges.add(lane);
    }
    while (lanes.isNotEmpty && lanes.last == null) {
      lanes.removeLast();
    }
    rows.add(GraphRow(column, lanes.length > column ? lanes.length : column + 1, merges));
  }
  return rows;
}

/// One file of a multi-file diff (`git show`, `git diff`).
class FileDiff {
  const FileDiff(this.path, this.text);

  final String path;
  final String text;

  List<DiffLine?> get lines => parseUnifiedDiff(text);
}

/// Splits a diff of several files at its `diff --git a/… b/…` lines.
List<FileDiff> splitFileDiffs(String diff) {
  final out = <FileDiff>[];
  final re = RegExp(r'^diff --git a/(.*) b/(.*)$', multiLine: true);
  final matches = re.allMatches(diff).toList();
  for (var i = 0; i < matches.length; i++) {
    final end = i + 1 < matches.length ? matches[i + 1].start : diff.length;
    out.add(FileDiff(matches[i].group(2)!, diff.substring(matches[i].start, end)));
  }
  return out;
}

/// The lines of a unified diff (`git diff`), with null between hunks. Headers are skipped.
List<DiffLine?> parseUnifiedDiff(String diff) {
  final out = <DiffLine?>[];
  var oldNo = 0, newNo = 0;
  var inHunk = false;
  for (final line in diff.split('\n')) {
    final hunk = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@').firstMatch(line);
    if (hunk != null) {
      if (out.isNotEmpty) out.add(null);
      oldNo = int.parse(hunk.group(1)!);
      newNo = int.parse(hunk.group(2)!);
      inHunk = true;
      continue;
    }
    if (!inHunk) continue;
    if (line.startsWith('diff --git')) {
      inHunk = false;
      continue;
    }
    if (line.startsWith('\\')) continue; // "\ No newline at end of file"
    if (line.startsWith('+')) {
      out.add(DiffLine(DiffKind.added, line.substring(1), newLine: newNo++));
    } else if (line.startsWith('-')) {
      out.add(DiffLine(DiffKind.removed, line.substring(1), oldLine: oldNo++));
    } else if (line.startsWith(' ')) {
      out.add(DiffLine(DiffKind.same, line.substring(1), oldLine: oldNo++, newLine: newNo++));
    }
  }
  return out;
}

/// A one-file unified diff split into its header and hunks, so a single hunk can be applied on its own.
class PatchHunks {
  PatchHunks(this.header, this.hunks);

  /// `diff --git`, `index`, `---`, `+++` lines.
  final String header;

  /// Each starts with its `@@` line.
  final List<String> hunks;

  /// A patch with only hunk [i].
  String patchFor(int i) => '$header${hunks[i]}';

  static PatchHunks parse(String diff) {
    final lines = diff.split('\n');
    final header = StringBuffer();
    final hunks = <String>[];
    StringBuffer? current;
    for (final (i, l) in lines.indexed) {
      if (i == lines.length - 1 && l.isEmpty) break;
      if (l.startsWith('@@')) {
        if (current != null) hunks.add('$current');
        current = StringBuffer();
      }
      (current ?? header).writeln(l);
    }
    if (current != null) hunks.add('$current');
    return PatchHunks('$header', hunks);
  }
}

class BlameLine {
  const BlameLine({required this.hash, required this.author, required this.time, required this.summary, required this.text});

  final String hash;
  final String author;
  final DateTime time;
  final String summary;
  final String text;

  String get short => hash.substring(0, 7);

  /// Not committed yet.
  bool get uncommitted => hash.startsWith('0000000');
}

/// Reads `git blame --line-porcelain`.
List<BlameLine> parseBlame(String out) {
  final result = <BlameLine>[];
  String? hash, author, summary;
  var time = 0;
  for (final line in out.split('\n')) {
    if (line.startsWith('\t')) {
      result.add(BlameLine(
        hash: hash ?? '',
        author: author ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(time * 1000),
        summary: summary ?? '',
        text: line.substring(1),
      ));
      continue;
    }
    final space = line.indexOf(' ');
    final key = space < 0 ? line : line.substring(0, space);
    final value = space < 0 ? '' : line.substring(space + 1);
    if (RegExp(r'^[0-9a-f]{40}$').hasMatch(key)) {
      hash = key;
    } else if (key == 'author') {
      author = value;
    } else if (key == 'author-time') {
      time = int.tryParse(value) ?? 0;
    } else if (key == 'summary') {
      summary = value;
    }
  }
  return result;
}

/// A conflicted file: plain text and conflict blocks in order.
class ConflictFile {
  ConflictFile(this.parts);

  /// Either a String (unchanged text, with line breaks) or a [ConflictBlock].
  final List<Object> parts;

  Iterable<ConflictBlock> get blocks => parts.whereType<ConflictBlock>();

  /// Parses `<<<<<<<` / `|||||||` (diff3 base, dropped) / `=======` / `>>>>>>>` markers.
  static ConflictFile parse(String text) {
    final parts = <Object>[];
    final plain = StringBuffer();
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length) {
      final l = lines[i];
      if (l.startsWith('<<<<<<<')) {
        if (plain.isNotEmpty) parts.add('$plain');
        plain.clear();
        final ours = <String>[], theirs = <String>[];
        var side = ours;
        var base = false;
        final oursLabel = l.length > 8 ? l.substring(8) : '';
        var theirsLabel = '';
        i++;
        while (i < lines.length && !lines[i].startsWith('>>>>>>>')) {
          final m = lines[i];
          if (m.startsWith('|||||||')) {
            base = true;
          } else if (m.startsWith('=======')) {
            base = false;
            side = theirs;
          } else if (!base) {
            side.add(m);
          }
          i++;
        }
        if (i < lines.length) theirsLabel = lines[i].length > 8 ? lines[i].substring(8) : '';
        parts.add(ConflictBlock(ours, theirs, oursLabel: oursLabel, theirsLabel: theirsLabel));
        i++;
        continue;
      }
      plain.write(l);
      if (i < lines.length - 1) plain.write('\n');
      i++;
    }
    if (plain.isNotEmpty) parts.add('$plain');
    return ConflictFile(parts);
  }

  /// The text with each block resolved by its [ConflictBlock.choice] (unresolved blocks keep their markers).
  String resolve() {
    final out = StringBuffer();
    for (final p in parts) {
      if (p is String) {
        out.write(p);
      } else {
        out.write((p as ConflictBlock).resolved());
      }
    }
    return '$out';
  }
}

enum ConflictChoice { ours, theirs, both }

class ConflictBlock {
  ConflictBlock(this.ours, this.theirs, {this.oursLabel = '', this.theirsLabel = ''});

  final List<String> ours;
  final List<String> theirs;
  final String oursLabel;
  final String theirsLabel;
  ConflictChoice? choice;

  String resolved() {
    final lines = switch (choice) {
      ConflictChoice.ours => ours,
      ConflictChoice.theirs => theirs,
      ConflictChoice.both => [...ours, ...theirs],
      null => ['<<<<<<< $oursLabel', ...ours, '=======', ...theirs, '>>>>>>> $theirsLabel'],
    };
    return lines.isEmpty ? '' : '${lines.join('\n')}\n';
  }
}

/// A merge, rebase, cherry-pick or revert that stopped (on conflicts) and waits to be continued or aborted.
enum GitOperation { merge, rebase, cherryPick, revert }

class GitStash {
  const GitStash(this.ref, this.message, this.time);

  /// `stash@{0}`.
  final String ref;
  final String message;
  final DateTime time;
}
