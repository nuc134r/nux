import 'dart:convert';

import 'package:nux_backend/nux_backend.dart';

import 'git_model.dart';
import 'git_status.dart';

export 'git_model.dart' show parseUnifiedDiff;

/// A git command that did not succeed; [output] is what git said.
class GitException implements Exception {
  const GitException(
    this.command,
    this.output, {
    this.diverged = false,
    this.noUpstream = false,
    this.needsCredentials = false,
    this.rejected = false,
    this.notMerged = false,
  });

  final String command;
  final String output;

  /// `pull` refused because the branches diverged (pick rebase or merge).
  final bool diverged;

  /// `push` has nowhere to go yet (the branch has no upstream).
  final bool noUpstream;

  /// The remote wanted a username and password (or they were wrong).
  final bool needsCredentials;

  /// `push` was refused because the server has commits this branch lacks (force-with-lease can override).
  final bool rejected;

  /// `branch -d` refused: the branch has commits that are nowhere else.
  final bool notMerged;

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

  /// The last git command run, as one would type it (no credentials, no helper), for "equivalent command".
  String? lastCommand;

  Future<String> _git(String args, {bool okOnOne = false, bool network = false}) async {
    lastCommand = 'git $args';
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
      rejected: out.contains('[rejected]') || out.contains('non-fast-forward') || out.contains('fetch first'),
      notMerged: out.contains('not fully merged'),
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

  Future<void> commit(String message, {bool amend = false, bool signOff = false}) =>
      _git('commit -q ${amend ? '--amend ' : ''}${signOff ? '-s ' : ''}-m ${shellQuote(message)}');

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

  /// Pushes the current branch; [setUpstream] publishes a new branch to origin; [force] overwrites the
  /// server's branch, but only if it is still where it was when last fetched (`--force-with-lease`).
  Future<void> push({bool setUpstream = false, bool force = false}) => _git(
    [
      'push -q',
      if (force) '--force-with-lease',
      if (setUpstream) '-u origin HEAD',
    ].join(' '),
    network: true,
  );

  /// Commits a push would send: on the branch and not on its upstream (null: no upstream yet).
  Future<List<GitCommit>?> outgoing() async {
    try {
      return parseLog(await _git('log --format=$gitLogFormat @{u}..HEAD'));
    } on GitException {
      return null;
    }
  }

  /// History, newest first: the current branch, or [all] branches, or one file ([path], following renames).
  Future<List<GitCommit>> log({int limit = 200, bool all = false, String? path}) => _git(
    'log --format=$gitLogFormat -n $limit${all ? ' --all' : ''}'
    '${path == null ? '' : ' --follow -- ${shellQuote(path)}'}',
  ).then(parseLog);

  /// A commit's full message.
  Future<String> message(String hash) async => (await _git('log -1 --format=%B ${shellQuote(hash)}')).trimRight();

  /// A commit's changes, file by file (against its first parent).
  Future<List<FileDiff>> show(String hash) async =>
      splitFileDiffs(await _git('show --format= --no-color --no-ext-diff -m --first-parent ${shellQuote(hash)}'));

  /// Who last changed each line of [path].
  Future<List<BlameLine>> blame(String path) async => parseBlame(await _git('blame --line-porcelain -- ${shellQuote(path)}'));

  /// Applies [patch] to the index (stage a hunk), or takes it back out with [reverse].
  Future<void> applyToIndex(String patch, {bool reverse = false}) async {
    final args = 'apply --cached ${reverse ? '-R ' : ''}--whitespace=nowarn -';
    lastCommand = 'git $args';
    // The patch goes through base64 in the command (any bytes survive the shell; no stdin needed) into
    // git's stdin. A pipe rather than <(…), which plain sh lacks.
    final r = await _runner.run(
      'cd ${shellQuote(folder)} && printf %s ${base64.encode(utf8.encode(patch))} | base64 -d | $_env git $args',
    );
    if (!r.ok) throw GitException('apply', '${r.stderr}\n${r.stdout}');
  }

  /// The merge, rebase, cherry-pick or revert waiting to be continued, if any.
  Future<GitOperation?> operation() async {
    final out = await _runner.run(
      'cd ${shellQuote(folder)} && for f in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do '
      'test -e "\$(git rev-parse --git-path \$f)" && echo \$f; done',
    );
    final found = out.stdout.split('\n').map((l) => l.trim()).toSet();
    if (found.contains('rebase-merge') || found.contains('rebase-apply')) return GitOperation.rebase;
    if (found.contains('MERGE_HEAD')) return GitOperation.merge;
    if (found.contains('CHERRY_PICK_HEAD')) return GitOperation.cherryPick;
    if (found.contains('REVERT_HEAD')) return GitOperation.revert;
    return null;
  }

  /// Goes on with [op] once its conflicts are resolved and staged (keeping the prepared message).
  Future<void> continueOperation(GitOperation op) => switch (op) {
    GitOperation.merge => _git('commit -q --no-edit'),
    GitOperation.rebase => _git('-c core.editor=true rebase --continue'),
    GitOperation.cherryPick => _git('-c core.editor=true cherry-pick --continue'),
    GitOperation.revert => _git('-c core.editor=true revert --continue'),
  };

  /// Gives up [op] and goes back to where it started.
  Future<void> abortOperation(GitOperation op) => _git('${switch (op) {
    GitOperation.merge => 'merge',
    GitOperation.rebase => 'rebase',
    GitOperation.cherryPick => 'cherry-pick',
    GitOperation.revert => 'revert',
  }} --abort');

  Future<List<GitStash>> stashes() async {
    final out = await _git('stash list --format=%gd%x1f%s%x1f%at');
    return [
      for (final l in out.split('\n'))
        if (l.trim().isNotEmpty)
          () {
            final f = l.split(gitFieldSep);
            return GitStash(f[0], f.length > 1 ? f[1] : '', DateTime.fromMillisecondsSinceEpoch((int.tryParse(f.length > 2 ? f[2] : '') ?? 0) * 1000));
          }(),
    ];
  }

  /// Puts the changes (untracked files too) away in a stash.
  Future<void> stash(String message) => _git('stash push -q -u${message.trim().isEmpty ? '' : ' -m ${shellQuote(message.trim())}'}');

  Future<void> stashApply(String ref, {bool drop = false}) => _git('stash ${drop ? 'pop' : 'apply'} -q ${shellQuote(ref)}');

  Future<void> stashDrop(String ref) => _git('stash drop -q ${shellQuote(ref)}');

  Future<void> renameBranch(String from, String to) => _git('branch -m ${shellQuote(from)} ${shellQuote(to)}');

  /// Deletes [branch]; refused (notMerged) when it has commits nowhere else, unless [force].
  Future<void> deleteBranch(String branch, {bool force = false}) => _git('branch ${force ? '-D' : '-d'} ${shellQuote(branch)}');

  /// Tags, newest first.
  Future<List<String>> tags() async => [
    for (final l in (await _git('tag --sort=-creatordate')).split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  /// Tags HEAD (annotated when there is a [message]).
  Future<void> createTag(String name, {String message = ''}) => _git(
    message.trim().isEmpty ? 'tag ${shellQuote(name)}' : 'tag -a ${shellQuote(name)} -m ${shellQuote(message.trim())}',
  );

  Future<void> pushTag(String name) => _git('push -q origin ${shellQuote(name)}', network: true);
}
