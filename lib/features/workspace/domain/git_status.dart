import 'package:nux_backend/nux_backend.dart';

/// How a file differs from the last commit, as the Version control list shows it.
enum GitChangeKind {
  modified('M'),
  added('A'),
  deleted('D'),
  renamed('R'),
  untracked('U'),
  conflict('!');

  const GitChangeKind(this.letter);

  final String letter;
}

class GitChange {
  const GitChange({required this.path, required this.kind, required this.staged, this.indexKind, this.worktreeKind});

  /// Absolute path on the host.
  final String path;

  /// The change as one letter (conflicts and untracked first).
  final GitChangeKind kind;

  /// Entirely in the index (would be committed as is).
  final bool staged;

  /// What is staged for this file (null: nothing).
  final GitChangeKind? indexKind;

  /// What is changed in the working tree and not staged (null: nothing).
  final GitChangeKind? worktreeKind;
}

GitChangeKind? _kindOf(String c) => switch (c) {
  'M' || 'T' => GitChangeKind.modified,
  'A' => GitChangeKind.added,
  'D' => GitChangeKind.deleted,
  'R' || 'C' => GitChangeKind.renamed,
  '?' => GitChangeKind.untracked,
  'U' => GitChangeKind.conflict,
  _ => null,
};

class GitStatus {
  const GitStatus({required this.root, required this.branch, required this.changes, this.ahead = 0, this.behind = 0});

  /// The repository's top folder.
  final String root;

  /// Null on a detached HEAD.
  final String? branch;
  final int ahead;
  final int behind;
  final List<GitChange> changes;

  /// Folders that contain a change (to mark them in the project tree).
  Set<String> get changedFolders {
    final out = <String>{};
    for (final c in changes) {
      var dir = posix.dirname(c.path);
      while (dir.length > 1 && out.add(dir)) {
        dir = posix.dirname(dir);
      }
    }
    return out;
  }

  GitChange? changeOf(String path) {
    for (final c in changes) {
      if (c.path == path) return c;
    }
    return null;
  }
}

/// The shell command whose output [parseGitStatus] reads: the top folder, then `status -z`.
String gitStatusCommand(String folder) =>
    'cd ${shellQuote(folder)} && git rev-parse --show-toplevel && git status --porcelain=v1 -b -z';

/// Reads [gitStatusCommand]'s output. Null when the folder is not in a git repository.
GitStatus? parseGitStatus(CommandResult result) {
  if (!result.ok) return null;
  final out = result.stdout;
  final newline = out.indexOf('\n');
  if (newline < 0) return null;
  final root = out.substring(0, newline).trim();
  final records = out.substring(newline + 1).split('\x00');
  String? branch;
  var ahead = 0, behind = 0;
  final changes = <GitChange>[];
  for (var i = 0; i < records.length; i++) {
    final r = records[i];
    if (r.isEmpty) continue;
    if (r.startsWith('## ')) {
      final head = r.substring(3);
      // `main...origin/main [ahead 1, behind 2]`, `HEAD (no branch)`, `No commits yet on main`
      final name = head.split(' [').first.split('...').first;
      branch = name.startsWith('HEAD (') ? null : name.replaceFirst('No commits yet on ', '');
      ahead = int.tryParse(RegExp(r'ahead (\d+)').firstMatch(head)?.group(1) ?? '') ?? 0;
      behind = int.tryParse(RegExp(r'behind (\d+)').firstMatch(head)?.group(1) ?? '') ?? 0;
      continue;
    }
    if (r.length < 4) continue;
    final x = r[0], y = r[1];
    final path = r.substring(3);
    // A rename or copy is followed by its old path, which is not listed separately.
    if (x == 'R' || x == 'C') i++;
    final kind = switch ((x, y)) {
      ('?', '?') => GitChangeKind.untracked,
      ('U', _) || (_, 'U') || ('A', 'A') || ('D', 'D') => GitChangeKind.conflict,
      ('R', _) || ('C', _) => GitChangeKind.renamed,
      ('A', _) => GitChangeKind.added,
      ('D', _) || (_, 'D') => GitChangeKind.deleted,
      _ => GitChangeKind.modified,
    };
    final staged = x != ' ' && x != '?' && y == ' ';
    final conflict = kind == GitChangeKind.conflict;
    changes.add(
      GitChange(
        path: posix.join(root, path),
        kind: kind,
        staged: staged,
        indexKind: conflict || x == '?' ? null : _kindOf(x),
        worktreeKind: conflict ? GitChangeKind.conflict : _kindOf(y),
      ),
    );
  }
  return GitStatus(root: root, branch: branch, ahead: ahead, behind: behind, changes: changes);
}
