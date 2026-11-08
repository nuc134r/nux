import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../files/presentation/file_dialogs.dart';
import '../../settings/data/settings_repository.dart' show TextSizeKind;
import '../../settings/presentation/text_size_controls.dart';
import '../../viewer/presentation/viewer_view.dart' show DiffLinesView, diffMenuItems;
import '../domain/git_model.dart';
import 'git_activity_view.dart';
import '../domain/git_repo.dart';
import '../domain/git_status.dart';

/// The colour of a change letter.
Color changeColor(GitChangeKind kind, ColorScheme scheme) => switch (kind) {
  GitChangeKind.modified => const Color(0xFFE2B93D),
  GitChangeKind.added || GitChangeKind.untracked => const Color(0xFF73C991),
  GitChangeKind.deleted || GitChangeKind.conflict => scheme.error,
  GitChangeKind.renamed => const Color(0xFF6CB6FF),
};

/// Runs a git [action]; shows [done] or the error in a snackbar, then [refresh]es.
Future<bool> runGit(
  BuildContext context,
  Future<void> Function() action, {
  required Future<void> Function() refresh,
  String? done,
  GitRepo? repo,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    await action();
    final command = repo?.lastCommand;
    if (done != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(done),
          persist: false,
          // The same in a terminal: what nux just ran (credentials and helpers left out).
          action: command == null
              ? null
              : SnackBarAction(
                  label: l10n.gitCommand,
                  onPressed: () => showDialog<void>(
                    context: navigator.context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.equivalentCommand),
                      content: SelectableText(command, style: const TextStyle(fontFamily: 'monospace')),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: command));
                            Navigator.pop(context);
                          },
                          child: Text(l10n.copy),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      );
    }
    return true;
  } on GitException catch (e) {
    final activity = repo?.activity;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.gitFailed(e.command, e.toString())),
        // The whole output, in the git output sheet.
        action: activity == null
            ? null
            : SnackBarAction(label: l10n.details, onPressed: () => showGitOutput(navigator.context, activity)),
      ),
    );
    return false;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric('$e'))));
    return false;
  } finally {
    await refresh();
  }
}

/// Pull, fast-forward only; when the branches diverged, explains and asks: rebase or merge.
Future<void> gitPull(BuildContext context, GitRepo repo, Future<void> Function() refresh) async {
  final l10n = context.l10n;
  try {
    await repo.pull();
    if (context.mounted) showSnack(context, l10n.pulled);
  } on GitException catch (e) {
    if (!context.mounted) return;
    if (!e.diverged) {
      showSnack(context, l10n.gitFailed(e.command, e.toString()));
    } else {
      final how = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.divergedTitle),
          content: Text(l10n.divergedBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.merge)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.rebase)),
          ],
        ),
      );
      if (how != null && context.mounted) {
        await runGit(
          context,
          () => repo.pull(rebase: how),
          refresh: () async {},
          done: l10n.pulled,
        );
      }
    }
  }
  await refresh();
}

/// Push; a branch with no upstream is offered to be published to origin.
Future<void> gitPush(BuildContext context, GitRepo repo, String? branch, Future<void> Function() refresh) async {
  final l10n = context.l10n;
  try {
    await repo.push();
    if (context.mounted) showSnack(context, l10n.pushed);
  } on GitException catch (e) {
    if (!context.mounted) return;
    if (!e.noUpstream) {
      showSnack(context, l10n.gitFailed(e.command, e.toString()));
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.publishBranchTitle(branch ?? 'HEAD')),
          content: Text(l10n.publishBranchBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.publish)),
          ],
        ),
      );
      if (ok == true && context.mounted) {
        await runGit(context, () => repo.push(setUpstream: true), refresh: () async {}, done: l10n.pushed);
      }
    }
  }
  await refresh();
}

/// The branches to switch to, and New branch (opened from the branch line of the workspace card).
Future<void> showBranchMenu(BuildContext anchor, GitRepo repo, Future<void> Function() refresh) async {
  final l10n = anchor.l10n;
  final List<String> branches;
  try {
    branches = await repo.branches();
  } on GitException catch (e) {
    if (anchor.mounted) showSnack(anchor, l10n.gitFailed(e.command, e.toString()));
    return;
  }
  if (!anchor.mounted) return;
  await showNuxMenu(
    anchor,
    beside: true,
    (_) => [
      for (final (i, b) in branches.indexed)
        NuxMenuAction(
          icon: null,
          label: b,
          checked: i == 0,
          onSelected: i == 0 ? () {} : () => gitSwitch(anchor, repo, b, refresh),
        ),
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.add,
        label: l10n.newBranch,
        onSelected: () async {
          final name = await askText(anchor, title: l10n.newBranch, label: l10n.branchName);
          if (name == null || name.trim().isEmpty || !anchor.mounted) return;
          await runGit(anchor, () => repo.createBranch(name.trim()), refresh: refresh, repo: repo);
        },
      ),
      if (branches.isNotEmpty)
        NuxMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.renameBranch,
          onSelected: () async {
            final current = branches.first;
            final name = await askText(anchor, title: l10n.renameBranch, label: l10n.branchName, initial: current);
            if (name == null || name.trim().isEmpty || name.trim() == current || !anchor.mounted) return;
            await runGit(anchor, () => repo.renameBranch(current, name.trim()), refresh: refresh, repo: repo);
          },
        ),
      if (branches.length > 1)
        NuxMenuSubmenu(
          icon: Icons.delete_outline,
          label: l10n.deleteBranch,
          items: [
            for (final b in branches.skip(1))
              NuxMenuAction(icon: null, label: b, onSelected: () => _deleteBranch(anchor, repo, b, refresh)),
          ],
        ),
    ],
  );
}

/// Switches to [branch]. With uncommitted changes, asks first: carry them over, or stash them (they wait in
/// Stashes). When carrying fails because the branch changes the same files, offers to stash instead.
Future<void> gitSwitch(BuildContext context, GitRepo repo, String branch, Future<void> Function() refresh) async {
  final l10n = context.l10n;
  final GitStatus? status;
  try {
    status = await repo.status();
  } catch (e) {
    if (context.mounted) showSnack(context, l10n.errorGeneric('$e'));
    return;
  }
  if (!context.mounted) return;
  var stash = false;
  final changes = status?.changes.length ?? 0;
  if (changes > 0) {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchWithChangesTitle(branch)),
        content: Text(l10n.switchWithChangesBody(changes)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.stashThem)),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.carryThem)),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    stash = choice;
  }
  final from = status?.branch ?? 'HEAD';
  Future<void> stashAndSwitch() async {
    await repo.stash(l10n.stashBeforeSwitch(from, branch));
    await repo.switchTo(branch);
  }

  if (stash) {
    await runGit(context, stashAndSwitch, refresh: refresh, repo: repo, done: l10n.switchedStashed(branch));
    return;
  }
  try {
    await repo.switchTo(branch);
    await refresh();
  } on GitException catch (e) {
    if (!context.mounted) return;
    if (!e.output.contains('would be overwritten')) {
      showSnack(context, l10n.gitFailed(e.command, e.toString()));
      await refresh();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cannotCarryTitle),
        content: Text(l10n.cannotCarryBody(branch)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.stashThem)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGit(context, stashAndSwitch, refresh: refresh, repo: repo, done: l10n.switchedStashed(branch));
    } else {
      await refresh();
    }
  }
}

/// Deletes [branch] after asking; when it has commits nowhere else, asks again before forcing.
Future<void> _deleteBranch(BuildContext context, GitRepo repo, String branch, Future<void> Function() refresh) async {
  final l10n = context.l10n;
  Future<bool> confirm(String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.deleteBranchTitle(branch)),
          content: body.isEmpty ? null : Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;
  if (!await confirm('', l10n.delete) || !context.mounted) return;
  try {
    await repo.deleteBranch(branch);
  } on GitException catch (e) {
    if (!context.mounted) return;
    if (!e.notMerged) {
      showSnack(context, l10n.gitFailed(e.command, e.toString()));
    } else if (await confirm(l10n.branchNotMerged(branch), l10n.deleteAnyway) && context.mounted) {
      await runGit(context, () => repo.deleteBranch(branch, force: true), refresh: () async {}, repo: repo);
    }
  }
  await refresh();
}

/// Version control: a commit box, then Staged and Changes, each file with stage / unstage. Tap a file for
/// its diff; long-press a change to discard it.
class GitPanel extends StatefulWidget {
  const GitPanel({
    super.key,
    required this.repo,
    required this.status,
    required this.loaded,
    required this.onRefresh,
    required this.onOpen,
    this.operation,
    this.onResolve,
  });

  final GitRepo? repo;
  final GitStatus? status;
  final bool loaded;
  final Future<void> Function() onRefresh;
  final void Function(String path) onOpen;

  /// A merge, rebase, cherry-pick or revert waiting for its conflicts (shown with Continue / Abort).
  final GitOperation? operation;

  /// Opens the resolver for a conflicted file.
  final void Function(String path)? onResolve;

  @override
  State<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends State<GitPanel> {
  final _message = TextEditingController();
  bool _amend = false;
  bool _signOff = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    await runGit(context, action, refresh: widget.onRefresh, done: done, repo: widget.repo);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleAmend(bool v) async {
    setState(() => _amend = v);
    // Amending starts from the last message.
    if (v && _message.text.trim().isEmpty && widget.repo != null) {
      try {
        _message.text = await widget.repo!.lastMessage();
      } on GitException {
        // No commit yet: nothing to amend from.
      }
    }
  }

  Future<void> _discard(GitChange c) async {
    final l10n = context.l10n;
    final untracked = c.worktreeKind == GitChangeKind.untracked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardChangesGitTitle(posix.basename(c.path))),
        content: Text(untracked ? l10n.deleteUntrackedBody : l10n.discardChangesGitBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.discardChanges)),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.repo!.discard(c.path, untracked: untracked));
  }

  void _showDiff(GitChange c, {required bool staged}) {
    final repo = widget.repo;
    if (repo == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: _DiffScreen(
          repo: repo,
          change: c,
          staged: staged,
          onStage: () => _run(() => staged ? repo.unstage([c.path]) : repo.stage([c.path])),
          onHunk: (patch) => _run(() => repo.applyToIndex(patch, reverse: staged)),
          onOpen: c.worktreeKind == GitChangeKind.deleted ? null : () => widget.onOpen(c.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final git = widget.status;
    final repo = widget.repo;
    if (!widget.loaded) return const Center(child: CircularProgressIndicator());
    if (git == null || repo == null) return Center(child: Text(l10n.notGitRepo));
    final staged = [
      for (final c in git.changes)
        if (c.indexKind != null) c,
    ];
    final changed = [
      for (final c in git.changes)
        if (c.worktreeKind != null) c,
    ];
    final canCommit = !_busy && _message.text.trim().isNotEmpty && (staged.isNotEmpty || _amend);
    String folderOf(String path) {
      final dir = posix.dirname(path);
      return posix.isWithin(git.root, dir) ? posix.relative(dir, from: git.root) : '';
    }

    Widget section(String title, int count, String action, VoidCallback? onAction) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text('$title  $count', style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
          ),
          if (count > 0) TextButton(onPressed: _busy ? null : onAction, child: Text(action)),
        ],
      ),
    );

    Widget row(GitChange c, GitChangeKind kind, {required bool inIndex}) => Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: c.kind == GitChangeKind.conflict && widget.onResolve != null
            ? () => widget.onResolve!(c.path)
            : () => _showDiff(c, staged: inIndex),
        onLongPress: inIndex ? null : () => _discard(c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
          child: Row(
            children: [
              ChangeLetter(kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      posix.basename(c.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: kind == GitChangeKind.deleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (folderOf(c.path).isNotEmpty)
                      StartEllipsisText(
                        folderOf(c.path),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: inIndex ? l10n.unstage : l10n.stage,
                icon: Icon(inIndex ? Icons.remove : Icons.add, size: 20),
                onPressed: _busy ? null : () => _run(() => inIndex ? repo.unstage([c.path]) : repo.stage([c.path])),
              ),
            ],
          ),
        ),
      ),
    );

    final op = widget.operation;
    final conflicts = git.changes.where((c) => c.kind == GitChangeKind.conflict).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      children: [
        if (op != null)
          Card(
            margin: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            color: scheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (op) {
                    GitOperation.merge => l10n.operationMerge,
                    GitOperation.rebase => l10n.operationRebase,
                    GitOperation.cherryPick => l10n.operationCherryPick,
                    GitOperation.revert => l10n.operationRevert,
                  }, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onTertiaryContainer)),
                  Text(
                    l10n.conflictsLeft(conflicts),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : () => _run(() => repo.abortOperation(op)),
                        child: Text(l10n.abortOperation),
                      ),
                      FilledButton(
                        onPressed: _busy || conflicts > 0 ? null : () => _run(() => repo.continueOperation(op)),
                        child: Text(l10n.continueOperation),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: TextField(
            controller: _message,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(isDense: true, hintText: l10n.commitMessage),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              // The chips wrap under each other in a narrow drawer.
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(l10n.amend),
                      selected: _amend,
                      onSelected: _busy ? null : _toggleAmend,
                    ),
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(l10n.signOff),
                      selected: _signOff,
                      onSelected: _busy ? null : (v) => setState(() => _signOff = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.commit),
                onPressed: canCommit
                    ? () => _run(() async {
                        await repo.commit(_message.text.trim(), amend: _amend, signOff: _signOff);
                        _message.clear();
                        _amend = false;
                      }, done: l10n.committed)
                    : null,
              ),
            ],
          ),
        ),
        SizedBox(height: 3, child: _busy ? const LinearProgressIndicator(minHeight: 3) : null),
        if (staged.isEmpty && changed.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noChanges, textAlign: TextAlign.center),
          ),
        if (staged.isNotEmpty) ...[
          section(l10n.staged, staged.length, l10n.unstageAll, () => _run(() => repo.unstage([git.root]))),
          for (final c in staged) row(c, c.indexKind!, inIndex: true),
        ],
        if (changed.isNotEmpty) ...[
          section(
            l10n.changesSection,
            changed.length,
            l10n.stageAll,
            () => _run(() => repo.stage([for (final c in changed) c.path])),
          ),
          for (final c in changed) row(c, c.worktreeKind!, inIndex: false),
        ],
      ],
    );
  }
}

/// M / A / D / R / U / ! in a small tinted box.
class ChangeLetter extends StatelessWidget {
  const ChangeLetter(this.kind, {super.key, this.staged = false});

  final GitChangeKind kind;
  final bool staged;

  @override
  Widget build(BuildContext context) {
    final color = changeColor(kind, Theme.of(context).colorScheme);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(5)),
      child: Text(
        kind.letter,
        style: TextStyle(fontSize: 11, fontWeight: staged ? FontWeight.w800 : FontWeight.w600, color: color),
      ),
    );
  }
}

/// One file's diff (staged or not), with Stage / Unstage and Open file.
class _DiffScreen extends ConsumerStatefulWidget {
  const _DiffScreen({
    required this.repo,
    required this.change,
    required this.staged,
    required this.onStage,
    required this.onHunk,
    required this.onOpen,
  });

  final GitRepo repo;
  final GitChange change;
  final bool staged;
  final VoidCallback onStage;

  /// Stages (or, for a staged diff, unstages) one part given as a patch.
  final void Function(String patch) onHunk;
  final VoidCallback? onOpen;

  @override
  ConsumerState<_DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends ConsumerState<_DiffScreen> {
  late final Future<String> _diff = widget.repo.diff(
    widget.change.path,
    staged: widget.staged,
    untracked: widget.change.worktreeKind == GitChangeKind.untracked && !widget.staged,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(posix.basename(widget.change.path)),
        actions: [
          if (widget.onOpen != null)
            IconButton(
              tooltip: l10n.open,
              icon: const Icon(Icons.description_outlined),
              onPressed: () {
                Navigator.pop(context);
                widget.onOpen!();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                widget.onStage();
              },
              child: Text(widget.staged ? l10n.unstage : l10n.stage),
            ),
          ),
          NuxMenuButton(tooltip: l10n.more, items: (context) => diffMenuItems(context, ref)),
        ],
      ),
      body: PinchTextSize(
        kind: TextSizeKind.diff,
        child: FutureBuilder<String>(
          future: _diff,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(l10n.errorGeneric('${snap.error}')));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final lines = parseUnifiedDiff(snap.data!);
            if (lines.isEmpty) return Center(child: Text(l10n.binaryOrEmptyDiff));
            final untracked = widget.change.worktreeKind == GitChangeKind.untracked && !widget.staged;
            final patch = PatchHunks.parse(snap.data!);
            if (untracked || patch.hunks.length < 2) return DiffLinesView(lines: lines);
            // Several parts: each can be staged (or unstaged) on its own.
            return ListView(
              children: [
                for (final (i, hunk) in patch.hunks.indexed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hunk.split('\n').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onHunk(patch.patchFor(i));
                              },
                              child: Text(widget.staged ? l10n.unstageHunk : l10n.stageHunk),
                            ),
                          ],
                        ),
                      ),
                      DiffLinesView(lines: parseUnifiedDiff('${patch.header}$hunk'), shrinkWrap: true),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
