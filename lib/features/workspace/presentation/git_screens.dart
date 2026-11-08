import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../files/presentation/file_dialogs.dart';
import '../../settings/data/settings_repository.dart' show TextSizeKind;
import '../../settings/presentation/text_size_controls.dart';
import '../../viewer/presentation/viewer_view.dart' show DiffLinesView, diffMenuItems;
import '../domain/git_model.dart';
import '../domain/git_repo.dart';
import 'git_panel.dart';

Future<T?> _fullScreen<T>(BuildContext context, Widget child) => showDialog<T>(
  context: context,
  builder: (_) => Dialog.fullscreen(child: child),
);

String _when(BuildContext context, DateTime t) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(t);

/// The history of the branch (or all branches, or one file) with a small graph; tap a commit for its changes.
Future<void> showHistory(BuildContext context, GitRepo repo, {String? path}) =>
    _fullScreen(context, _HistoryScreen(repo: repo, path: path));

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen({required this.repo, this.path});

  final GitRepo repo;
  final String? path;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  bool _all = false;
  late Future<List<GitCommit>> _log = _load();

  Future<List<GitCommit>> _load() => widget.repo.log(all: _all, path: widget.path);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.history, style: theme.textTheme.titleLarge),
          subtitle: widget.path == null
              ? Text(_all ? l10n.allBranches : l10n.thisBranch)
              : StartEllipsisText(widget.path!),
        ),
        actions: [
          if (widget.path == null)
            NuxMenuButton(
              tooltip: l10n.more,
              items: (_) => [
                NuxMenuAction(
                  icon: null,
                  label: l10n.thisBranch,
                  checked: !_all,
                  onSelected: () => setState(() {
                    _all = false;
                    _log = _load();
                  }),
                ),
                NuxMenuAction(
                  icon: null,
                  label: l10n.allBranches,
                  checked: _all,
                  onSelected: () => setState(() {
                    _all = true;
                    _log = _load();
                  }),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<List<GitCommit>>(
        future: _log,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(l10n.errorGeneric('${snap.error}')));
          final log = snap.data;
          if (log == null) return const Center(child: CircularProgressIndicator());
          if (log.isEmpty) return Center(child: Text(l10n.noCommits));
          final graph = graphLanes(log);
          final width = 12.0 * graph.map((r) => r.lanes).fold(1, (a, b) => a > b ? a : b) + 8;
          return ListView.builder(
            itemCount: log.length,
            itemBuilder: (context, i) {
              final c = log[i];
              return InkWell(
                onTap: () => showCommit(context, widget.repo, c),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: width,
                        child: CustomPaint(painter: _GraphPainter(graph[i], scheme.primary, scheme.tertiary)),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.refs.isNotEmpty)
                                Wrap(spacing: 4, runSpacing: 2, children: [for (final r in c.refs) _Ref(r)]),
                              Text(c.subject, maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(
                                '${c.short} · ${c.author} · ${_when(context, c.time)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A row of the graph: lanes passing through, the commit's dot, lines to its other parents' lanes.
class _GraphPainter extends CustomPainter {
  _GraphPainter(this.row, this.color, this.mergeColor);

  final GraphRow row;
  final Color color;
  final Color mergeColor;

  double _x(int lane) => 10 + lane * 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: .55)
      ..strokeWidth = 2;
    for (var l = 0; l < row.lanes; l++) {
      canvas.drawLine(Offset(_x(l), 0), Offset(_x(l), size.height), line);
    }
    final dotY = size.height / 2;
    final merge = Paint()
      ..color = mergeColor.withValues(alpha: .8)
      ..strokeWidth = 2;
    for (final m in row.merges) {
      canvas.drawLine(Offset(_x(row.column), dotY), Offset(_x(m), size.height), merge);
    }
    canvas.drawCircle(Offset(_x(row.column), dotY), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.row != row || old.color != color;
}

class _Ref extends StatelessWidget {
  const _Ref(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = name.startsWith('tag: ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tag ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name.replaceFirst('tag: ', ''),
        style: TextStyle(fontSize: 11, color: tag ? scheme.onTertiaryContainer : scheme.onSecondaryContainer),
      ),
    );
  }
}

/// A commit: its message, author and date, and each file's changes.
Future<void> showCommit(BuildContext context, GitRepo repo, GitCommit commit) =>
    _fullScreen(context, _CommitScreen(repo: repo, commit: commit));

class _CommitScreen extends ConsumerWidget {
  const _CommitScreen({required this.repo, required this.commit});

  final GitRepo repo;
  final GitCommit commit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.commitDetails} ${commit.short}'),
        actions: [
          NuxMenuButton(
            tooltip: l10n.more,
            items: (_) => [
              NuxMenuAction(
                icon: Icons.copy,
                label: l10n.copyHash,
                onSelected: () => Clipboard.setData(ClipboardData(text: commit.hash)),
              ),
              ...diffMenuItems(context, ref),
            ],
          ),
        ],
      ),
      body: PinchTextSize(
        kind: TextSizeKind.diff,
        child: FutureBuilder(
          future: Future.wait([repo.message(commit.hash), repo.show(commit.hash)]),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text(l10n.errorGeneric('${snap.error}')));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final message = snap.data![0] as String;
            final files = snap.data![1] as List<FileDiff>;
            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SelectableText(message, style: theme.textTheme.bodyLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${commit.author} <${commit.email}> · ${_when(context, commit.time)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                for (final f in files)
                  ExpansionTile(
                    title: Text(posix.basename(f.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: posix.dirname(f.path) == '.' ? null : StartEllipsisText(posix.dirname(f.path)),
                    initiallyExpanded: files.length <= 3,
                    children: [DiffLinesView(lines: f.lines, shrinkWrap: true)],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Who last changed each line of [path]; tap a line for its commit.
Future<void> showBlame(BuildContext context, GitRepo repo, String path) =>
    _fullScreen(context, _BlameScreen(repo: repo, path: path));

class _BlameScreen extends StatelessWidget {
  const _BlameScreen({required this.repo, required this.path});

  final GitRepo repo;
  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures, height: 1.45);
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.blame, style: theme.textTheme.titleLarge),
          subtitle: StartEllipsisText(path),
        ),
      ),
      body: FutureBuilder<List<BlameLine>>(
        future: repo.blame(path),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(l10n.errorGeneric('${snap.error}')));
          final lines = snap.data;
          if (lines == null) return const Center(child: CircularProgressIndicator());
          // Runs of lines from the same commit share a shade (alternating), and show the commit once.
          var shade = false;
          final shades = <bool>[];
          for (var i = 0; i < lines.length; i++) {
            if (i > 0 && lines[i].hash != lines[i - 1].hash) shade = !shade;
            shades.add(shade);
          }
          return ListView.builder(
            itemCount: lines.length,
            itemBuilder: (context, i) {
              final b = lines[i];
              final first = i == 0 || lines[i - 1].hash != b.hash;
              return InkWell(
                onTap: b.uncommitted
                    ? null
                    : () => showCommit(
                        context,
                        repo,
                        GitCommit(
                          hash: b.hash,
                          author: b.author,
                          email: '',
                          time: b.time,
                          parents: const [],
                          subject: b.summary,
                        ),
                      ),
                child: Container(
                  color: shades[i] ? scheme.surfaceContainerLow : null,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 112,
                        child: first
                            ? Text(
                                b.uncommitted ? l10n.notCommittedYet : '${b.short} ${b.author}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: mono?.copyWith(color: scheme.primary),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.right,
                          style: mono?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(b.text, style: mono, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The stashes: apply, apply and drop, or drop each.
Future<void> showStashes(BuildContext context, GitRepo repo, Future<void> Function() refresh) =>
    _fullScreen(context, _StashesScreen(repo: repo, refresh: refresh));

class _StashesScreen extends StatefulWidget {
  const _StashesScreen({required this.repo, required this.refresh});

  final GitRepo repo;
  final Future<void> Function() refresh;

  @override
  State<_StashesScreen> createState() => _StashesScreenState();
}

class _StashesScreenState extends State<_StashesScreen> {
  late Future<List<GitStash>> _list = widget.repo.stashes();

  Future<void> _run(Future<void> Function() action) async {
    await runGit(context, action, refresh: widget.refresh, repo: widget.repo);
    if (mounted) setState(() => _list = widget.repo.stashes());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.stashes)),
      body: FutureBuilder<List<GitStash>>(
        future: _list,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          if (list.isEmpty) return Center(child: Text(l10n.noStashes));
          return ListView(
            children: [
              for (final s in list)
                Builder(
                  builder: (row) => ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(s.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${s.ref} · ${_when(context, s.time)}'),
                    onTap: () => showNuxMenu(
                      row,
                      beside: true,
                      (_) => [
                        NuxMenuAction(
                          icon: Icons.unarchive_outlined,
                          label: l10n.stashPop,
                          onSelected: () => _run(() => widget.repo.stashApply(s.ref, drop: true)),
                        ),
                        NuxMenuAction(
                          icon: Icons.content_copy,
                          label: l10n.stashApply,
                          onSelected: () => _run(() => widget.repo.stashApply(s.ref)),
                        ),
                        const NuxMenuDivider(),
                        NuxMenuAction(
                          icon: Icons.delete_outline,
                          label: l10n.stashDrop,
                          onSelected: () => _run(() => widget.repo.stashDrop(s.ref)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Asks for a note and stashes the changes.
Future<void> stashChanges(BuildContext context, GitRepo repo, Future<void> Function() refresh) async {
  final l10n = context.l10n;
  final note = await askText(context, title: l10n.stashChanges, label: l10n.stashMessage, confirm: l10n.stashChanges);
  if (note == null || !context.mounted) return;
  await runGit(context, () => repo.stash(note), refresh: refresh, done: l10n.stashed, repo: repo);
}

/// The tags; a new one on the current commit, optionally pushed.
Future<void> showTags(BuildContext context, GitRepo repo, Future<void> Function() refresh) =>
    _fullScreen(context, _TagsScreen(repo: repo, refresh: refresh));

class _TagsScreen extends StatefulWidget {
  const _TagsScreen({required this.repo, required this.refresh});

  final GitRepo repo;
  final Future<void> Function() refresh;

  @override
  State<_TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<_TagsScreen> {
  late Future<List<String>> _tags = widget.repo.tags();

  Future<void> _newTag() async {
    final l10n = context.l10n;
    final name = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.tagName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: message,
              decoration: InputDecoration(labelText: l10n.tagMessage),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.create)),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    await runGit(
      context,
      () => widget.repo.createTag(name.text.trim(), message: message.text),
      refresh: widget.refresh,
      repo: widget.repo,
    );
    if (mounted) setState(() => _tags = widget.repo.tags());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tags)),
      bottomNavigationBar: AddBar(label: l10n.newTag, icon: Icons.sell_outlined, onPressed: _newTag),
      body: FutureBuilder<List<String>>(
        future: _tags,
        builder: (context, snap) {
          final tags = snap.data;
          if (tags == null) return const Center(child: CircularProgressIndicator());
          if (tags.isEmpty) return Center(child: Text(l10n.noTags));
          return ListView(
            children: [
              for (final t in tags)
                Builder(
                  builder: (row) => ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(t),
                    onTap: () => showNuxMenu(
                      row,
                      beside: true,
                      (_) => [
                        NuxMenuAction(
                          icon: Icons.cloud_upload_outlined,
                          label: l10n.pushTag,
                          onSelected: () => runGit(
                            context,
                            () => widget.repo.pushTag(t),
                            refresh: widget.refresh,
                            done: l10n.pushed,
                            repo: widget.repo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Resolves one conflicted file block by block (yours, theirs, both), then saves it and stages it.
Future<void> showConflictResolver(
  BuildContext context, {
  required GitRepo repo,
  required String path,
  required FileSystem fs,
  required Future<void> Function() refresh,
}) => _fullScreen(context, _ConflictScreen(repo: repo, path: path, fs: fs, refresh: refresh));

class _ConflictScreen extends StatefulWidget {
  const _ConflictScreen({required this.repo, required this.path, required this.fs, required this.refresh});

  final GitRepo repo;
  final String path;
  final FileSystem fs;
  final Future<void> Function() refresh;

  @override
  State<_ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<_ConflictScreen> {
  ConflictFile? _file;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.fs
        .readBytes(widget.path)
        .then(
          (b) => setState(() => _file = ConflictFile.parse(utf8.decode(b, allowMalformed: true))),
          onError: (Object e) => setState(() => _error = e),
        );
  }

  Future<void> _save() async {
    final file = _file!;
    setState(() => _saving = true);
    final ok = await runGit(
      context,
      () async {
        await widget.fs.writeBytes(widget.path, Uint8List.fromList(utf8.encode(file.resolve())));
        await widget.repo.stage([widget.path]);
      },
      refresh: widget.refresh,
      repo: widget.repo,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = _file;
    final blocks = file?.blocks.toList() ?? const <ConflictBlock>[];
    final left = blocks.where((b) => b.choice == null).length;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: monoFont, fontFeatures: noLigatures, height: 1.4);
    Widget code(List<String> lines, Color tint) => Container(
      width: double.infinity,
      color: tint,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(lines.isEmpty ? ' ' : lines.join('\n'), style: mono),
    );
    var index = 0;
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.resolveConflicts, style: theme.textTheme.titleLarge),
          subtitle: StartEllipsisText(widget.path),
        ),
      ),
      bottomNavigationBar: file == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: left == 0 && !_saving ? _save : null,
                  child: Text(left == 0 ? l10n.markResolved : l10n.unresolvedLeft(left)),
                ),
              ),
            ),
      body: _error != null
          ? Center(child: Text(l10n.errorGeneric('$_error')))
          : file == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final part in file.parts)
                  if (part is String)
                    // Unchanged text between conflicts, shortened to its last lines for context.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_context(part), style: mono?.copyWith(color: scheme.onSurfaceVariant)),
                    )
                  else
                    () {
                      final b = part as ConflictBlock;
                      index++;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Text(l10n.conflictBlock(index, blocks.length), style: theme.textTheme.labelLarge),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
                              child: Text('${l10n.keepYours} ${b.oursLabel}', style: theme.textTheme.labelSmall),
                            ),
                            code(b.ours, Colors.blue.withValues(alpha: .12)),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                              child: Text('${l10n.keepTheirs} ${b.theirsLabel}', style: theme.textTheme.labelSmall),
                            ),
                            code(b.theirs, Colors.orange.withValues(alpha: .14)),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: SegmentedButton<ConflictChoice>(
                                emptySelectionAllowed: true,
                                segments: [
                                  ButtonSegment(value: ConflictChoice.ours, label: Text(l10n.keepYours)),
                                  ButtonSegment(value: ConflictChoice.theirs, label: Text(l10n.keepTheirs)),
                                  ButtonSegment(value: ConflictChoice.both, label: Text(l10n.keepBoth)),
                                ],
                                selected: {?b.choice},
                                onSelectionChanged: (v) => setState(() => b.choice = v.firstOrNull),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
              ],
            ),
    );
  }

  static String _context(String text) {
    final lines = text.split('\n');
    return lines.length <= 4 ? text : '⋯\n${lines.sublist(lines.length - 3).join('\n')}';
  }
}

/// Shows what a push would send, then pushes; a rejected push offers force-with-lease, explained.
Future<void> gitPushWithPreview(
  BuildContext context,
  GitRepo repo,
  String? branch,
  Future<void> Function() refresh,
) async {
  final l10n = context.l10n;
  final outgoing = await repo.outgoing();
  if (!context.mounted) return;
  if (outgoing == null) return gitPush(context, repo, branch, refresh); // a new branch: offered to publish
  final theme = Theme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.pushPreviewTitle(branch ?? 'HEAD')),
      content: outgoing.isEmpty
          ? Text(l10n.pushNothing)
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in outgoing)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.subject, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${c.short} · ${c.author}', style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.push)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await repo.push();
    if (context.mounted) showSnack(context, l10n.pushed);
  } on GitException catch (e) {
    if (!context.mounted) return;
    if (!e.rejected) {
      showSnack(context, l10n.gitFailed(e.command, e.toString()));
    } else {
      final force = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.pushRejectedTitle),
          content: Text(l10n.pushRejectedBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.forcePush)),
          ],
        ),
      );
      if (force == true && context.mounted) {
        await runGit(context, () => repo.push(force: true), refresh: () async {}, done: l10n.pushed, repo: repo);
      }
    }
  }
  await refresh();
}
