import 'package:nux_backend/nux_backend.dart';

import '../../viewer/domain/line_diff.dart';
import 'git_status.dart';

/// A git command that did not succeed; [output] is what git said.
class GitException implements Exception {
  const GitException(this.command, this.output, {this.diverged = false, this.noUpstream = false});

  final String command;
  final String output;

  /// `pull` refused because the branches diverged (pick rebase or merge).
  final bool diverged;

  /// `push` has nowhere to go yet (the branch has no upstream).
  final bool noUpstream;

  @override
  String toString() => output.trim().isEmpty ? 'git $command failed' : output.trim();
}

/// git in a workspace folder, run as commands on its host. Never prompts: a remote that needs a password
/// it does not have fails at once instead of hanging.
class GitRepo {
  GitRepo(this._runner, this.folder);

  final ProcessRunner _runner;
  final String folder;

  Future<String> _git(String args, {bool okOnOne = false}) async {
    final r = await _runner.run(
      'cd ${shellQuote(folder)} && GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes" git $args',
    );
    if (r.ok || (okOnOne && r.exitCode == 1)) return r.stdout;
    final out = '${r.stderr}\n${r.stdout}';
    throw GitException(
      args.split(' ').first,
      out,
      diverged: out.contains('diverging branches') || out.contains('Not possible to fast-forward'),
      noUpstream: out.contains('has no upstream branch'),
    );
  }

  String _paths(Iterable<String> paths) => paths.map(shellQuote).join(' ');

  Future<GitStatus?> status() async => parseGitStatus(await _runner.run(gitStatusCommand(folder)));

  Future<void> stage(Iterable<String> paths) => _git('add -A -- ${_paths(paths)}');

  Future<void> unstage(Iterable<String> paths) async {
    try {
      await _git('restore --staged -- ${_paths(paths)}');
    } on GitException {
      // Before the first commit there is no HEAD to restore from.
      await _git('rm -q --cached -r -- ${_paths(paths)}');
    }
  }

  /// Throws away unstaged changes to [path]; an untracked file is deleted.
  Future<void> discard(String path, {required bool untracked}) =>
      untracked ? _git('clean -f -q -- ${shellQuote(path)}') : _git('restore -- ${shellQuote(path)}');

  /// The unified diff of [path]: staged (index vs HEAD) or unstaged (working tree vs index). An untracked
  /// file shows as all added.
  Future<String> diff(String path, {bool staged = false, bool untracked = false}) => untracked
      ? _git('diff --no-color --no-ext-diff --no-index -- /dev/null ${shellQuote(path)}', okOnOne: true)
      : _git('diff --no-color --no-ext-diff ${staged ? '--cached ' : ''}-- ${shellQuote(path)}');

  Future<void> commit(String message, {bool amend = false}) =>
      _git('commit -q ${amend ? '--amend ' : ''}-m ${shellQuote(message)}');

  /// The last commit's message (to edit when amending).
  Future<String> lastMessage() async => (await _git('log -1 --format=%B')).trimRight();

  /// Local branches, the current one first.
  Future<List<String>> branches() async {
    final out = await _git("for-each-ref --format='%(HEAD)%(refname:short)' refs/heads");
    final lines = [
      for (final l in out.split('\n'))
        if (l.trim().isNotEmpty) l,
    ];
    lines.sort((a, b) => (b.startsWith('*') ? 1 : 0) - (a.startsWith('*') ? 1 : 0));
    return [for (final l in lines) l.substring(1).trim()];
  }

  Future<void> switchTo(String branch) => _git('switch -q ${shellQuote(branch)}');

  Future<void> createBranch(String name) => _git('switch -q -c ${shellQuote(name)}');

  Future<void> fetch() => _git('fetch -q --all --prune');

  /// Fast-forward only, unless [rebase] says how to combine diverged branches (true: rebase, false: merge).
  Future<void> pull({bool? rebase}) => _git(switch (rebase) {
    null => 'pull -q --no-rebase --ff-only',
    true => 'pull -q --rebase',
    false => 'pull -q --no-rebase --no-edit',
  });

  /// Pushes the current branch; [setUpstream] publishes a new branch to origin.
  Future<void> push({bool setUpstream = false}) => _git(setUpstream ? 'push -q -u origin HEAD' : 'push -q');
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
    if (!inHunk || line.isEmpty && oldNo == 0 && newNo == 0) continue;
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
