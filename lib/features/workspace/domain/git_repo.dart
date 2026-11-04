import 'dart:convert';

import 'package:nux_backend/nux_backend.dart';

import '../../viewer/domain/line_diff.dart';
import 'git_status.dart';

/// A git command that did not succeed; [output] is what git said.
class GitException implements Exception {
  const GitException(
    this.command,
    this.output, {
    this.diverged = false,
    this.noUpstream = false,
    this.needsCredentials = false,
  });

  final String command;
  final String output;

  /// `pull` refused because the branches diverged (pick rebase or merge).
  final bool diverged;

  /// `push` has nowhere to go yet (the branch has no upstream).
  final bool noUpstream;

  /// The remote wanted a username and password (or they were wrong).
  final bool needsCredentials;

  /// Where the credentials are for, from git's message (`https://example.com`), if it said.
  String? get remote => RegExp(r"for '([^']+)'").firstMatch(output)?.group(1);

  @override
  String toString() => output.trim().isEmpty ? 'git $command failed' : output.trim();
}

typedef GitCredentials = ({String username, String password});

/// git in a workspace folder, run as commands on its host. Never prompts on the host: a remote that needs
/// a password fails at once (instead of hanging); [askCredentials] is then asked and the command retried
/// with them, passed through stdin to a one-off credential helper (never in a command line or a file).
class GitRepo {
  GitRepo(this._runner, this.folder, {this.credentials, this.askCredentials});

  final ProcessRunner _runner;
  final String folder;

  /// Used for fetch, pull and push when set (e.g. remembered for the workspace).
  GitCredentials? credentials;

  /// Asked when the remote wants credentials; null cancels.
  final Future<GitCredentials?> Function(String? remote, {required bool retry})? askCredentials;

  static const _env = 'GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes"';

  /// A credential helper answering from two variables the command reads from stdin first.
  static final _helper = shellQuote(
    '!f() { test "\$1" = get && printf "username=%s\\npassword=%s\\n" "\$NUX_GIT_USER" "\$NUX_GIT_PASS"; }; f',
  );

  /// The command that runs `git args` with credentials read from the first two lines of stdin.
  static String withCredentialsCommand(String folder, String args) =>
      'cd ${shellQuote(folder)} && IFS= read -r NUX_GIT_USER && IFS= read -r NUX_GIT_PASS && '
      'export NUX_GIT_USER NUX_GIT_PASS && $_env git -c credential.helper= -c credential.helper=$_helper $args';

  Future<String> _git(String args, {bool okOnOne = false, bool network = false}) async {
    final creds = network ? credentials : null;
    final r = creds == null
        ? await _runner.run('cd ${shellQuote(folder)} && $_env git $args')
        : await _runWithCredentials(args, creds);
    if (r.ok || (okOnOne && r.exitCode == 1)) return r.stdout;
    final out = '${r.stderr}\n${r.stdout}';
    final error = GitException(
      args.split(' ').first,
      out,
      diverged: out.contains('diverging branches') || out.contains('Not possible to fast-forward'),
      noUpstream: out.contains('has no upstream branch'),
      needsCredentials:
          out.contains('could not read Username') ||
          out.contains('could not read Password') ||
          out.contains('Authentication failed') ||
          out.contains('Invalid username or password'),
    );
    final ask = askCredentials;
    if (network && error.needsCredentials && ask != null) {
      final given = await ask(error.remote, retry: creds != null);
      if (given != null) {
        credentials = given;
        return _git(args, okOnOne: okOnOne, network: true);
      }
    }
    throw error;
  }

  Future<CommandResult> _runWithCredentials(String args, GitCredentials c) async {
    final p = await _runner.start(withCredentialsCommand(folder, args));
    final out = p.stdout.cast<List<int>>().transform(utf8.decoder).join();
    final err = p.stderr.cast<List<int>>().transform(utf8.decoder).join();
    p.stdin.add(utf8.encode('${c.username}\n${c.password}\n'));
    final results = await Future.wait([out, err]);
    return CommandResult(exitCode: await p.exitCode, stdout: results[0], stderr: results[1]);
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

  Future<void> fetch() => _git('fetch -q --all --prune', network: true);

  /// Fast-forward only, unless [rebase] says how to combine diverged branches (true: rebase, false: merge).
  Future<void> pull({bool? rebase}) => _git(switch (rebase) {
    null => 'pull -q --no-rebase --ff-only',
    true => 'pull -q --rebase',
    false => 'pull -q --no-rebase --no-edit',
  }, network: true);

  /// Pushes the current branch; [setUpstream] publishes a new branch to origin.
  Future<void> push({bool setUpstream = false}) =>
      _git(setUpstream ? 'push -q -u origin HEAD' : 'push -q', network: true);
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
