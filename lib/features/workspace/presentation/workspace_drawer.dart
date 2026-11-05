import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/activity/activity_center.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../files/domain/file_listing.dart';
import '../../files/presentation/file_dialogs.dart';
import '../../files/presentation/files_view.dart' show EntryDetails, fileIcon;
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../data/tab_factory.dart';
import '../data/workspace.dart';
import '../data/workspace_access.dart';
import '../data/workspace_repository.dart';
import '../../../core/secure/secret_store.dart';
import '../domain/git_repo.dart';
import '../domain/git_status.dart';
import 'git_panel.dart';
import '../domain/git_activity.dart';
import '../domain/git_model.dart';
import 'git_activity_view.dart';
import 'git_screens.dart';
import '../../viewer/presentation/viewer_tab.dart';
import '../../../app/router.dart';
import 'workspace_find.dart';

/// What the drawer remembers between openings: the side shown and the open folders, per workspace.
class WorkspaceDrawerState {
  bool versionControl = false;
  final Map<String, Set<String>> expanded = {};

  /// The file last opened from the drawer or a finder, per workspace (the tree scrolls to it).
  final Map<String, String> lastOpened = {};

  /// The git commands run in each workspace, with their output (kept while the app runs).
  final Map<String, GitActivity> gitActivity = {};
}

/// Height of a tree row (fixed, so the tree can scroll straight to a file).
const _rowHeight = 38.0;

final workspaceDrawerStateProvider = Provider((ref) => WorkspaceDrawerState());

/// Opened from ☰ on the tab overview: the current workspace on top, its project tree (or its changes)
/// below, and Explorer / Version control at the bottom.
class WorkspaceDrawer extends ConsumerWidget {
  const WorkspaceDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switcher = ref.watch(workspaceSwitcherProvider);
    final width = math.min(MediaQuery.sizeOf(context).width * .86, 380.0);
    return Drawer(
      width: width,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: switcher,
          builder: (context, _) {
            final ws = switcher.current;
            return ws == null ? const _NoWorkspace() : _WorkspaceView(key: ValueKey(ws.id), workspace: ws);
          },
        ),
      ),
    );
  }
}

class _NoWorkspace extends ConsumerWidget {
  const _NoWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final hosts = {for (final c in ref.watch(connectionsProvider).value ?? const <Connection>[]) c.id: c.name};
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Card(title: l10n.noWorkspace, subtitle: l10n.noWorkspaceCard),
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
            child: Text(l10n.workspaces, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
          ),
        for (final w in all)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Material(
              color: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ref.read(workspaceSwitcherProvider).switchTo(w.id),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Icon(Icons.folder_special_outlined, color: scheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            StartEllipsisText(
                              '${hosts[w.connectionId] ?? ''} · ${w.rootPath}',
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: Text(l10n.newWorkspace),
            onPressed: () => newWorkspace(context, ref),
          ),
        ),
        // What a workspace is: only while there is none yet.
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              l10n.noWorkspaceHint,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// The workspace's name, host and folder, and its branch, with ⋮ for switching and managing.
class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, this.footer, this.activity, this.menu});

  final String title;
  final String? subtitle;
  final Widget? footer;

  /// Under the footer: the git command running (or just finished).
  final Widget? activity;

  /// Its ⋮ menu; none when null.
  final List<NuxMenuItem> Function(BuildContext)? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 8), footer!],
                ?activity,
              ],
            ),
          ),
          if (menu != null) NuxMenuButton(tooltip: context.l10n.more, items: menu!) else const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _WorkspaceView extends ConsumerStatefulWidget {
  const _WorkspaceView({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends ConsumerState<_WorkspaceView> {
  WorkspaceAccess? _access;
  Object? _error;
  final Map<String, List<FileEntry>> _children = {};
  final Set<String> _loading = {};
  GitStatus? _git;
  bool _gitLoaded = false;
  final _scroll = ScrollController();

  /// The file to show (and mark) in the tree: the open file of this workspace, else the last opened one.
  String? _target;

  Workspace get ws => widget.workspace;

  /// git in the workspace folder, once connected.
  GitRepo? get _repo => _access == null
      ? null
      : GitRepo(
          _access!.runner,
          ws.rootPath,
          credentials: _gitCredentials,
          activity: _activity,
          askCredentials: (remote, {required retry}) async {
            final c = await askGitCredentials(context, ref, ws, remote, retry: retry);
            if (c != null) _gitCredentials = c;
            return c;
          },
        );

  /// A merge, rebase, cherry-pick or revert waiting for its conflicts.
  GitOperation? _operation;

  /// Remembered (in the secret store) or given this session, for fetch / pull / push.
  GitCredentials? _gitCredentials;
  WorkspaceDrawerState get _state => ref.read(workspaceDrawerStateProvider);
  GitActivity get _activity => _state.gitActivity.putIfAbsent(
    ws.id,
    () => reportGitActivity(GitActivity(), ref.read(activityCenterProvider), ws.name),
  );
  Set<String> get _expanded => _state.expanded.putIfAbsent(ws.id, () => {});

  @override
  void initState() {
    super.initState();
    final current = ref.read(workspaceProvider).current;
    _target =
        current is ViewerTab && current.connectionId == ws.connectionId && posix.isWithin(ws.rootPath, current.path)
        ? current.path
        : _state.lastOpened[ws.id];
    _connect();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _access?.release();
    super.dispose();
  }

  /// Opens the folders down to [_target] and scrolls it into the middle of the tree.
  Future<void> _reveal() async {
    final target = _target;
    if (target == null || !posix.isWithin(ws.rootPath, target)) return;
    final dirs = <String>[];
    for (var d = posix.dirname(target); d != ws.rootPath && posix.isWithin(ws.rootPath, d); d = posix.dirname(d)) {
      dirs.insert(0, d);
    }
    for (final d in dirs) {
      if (!mounted) return;
      _expanded.add(d);
      if (!_children.containsKey(d)) await _list(d);
    }
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _rows().indexWhere((r) => r.$1.path == target);
      if (index < 0 || !_scroll.hasClients) return;
      final position = _scroll.position;
      final offset = index * _rowHeight - position.viewportDimension / 3;
      _scroll.jumpTo(offset.clamp(0, position.maxScrollExtent));
    });
  }

  Future<void> _connect() async {
    try {
      final access = await ref.read(workspaceOpenerProvider)(ws.connectionId);
      if (!mounted) return access.release();
      _access = access;
      _gitCredentials = await loadGitCredentials(ref, ws.id);
      await Future.wait([_list(ws.rootPath).then((_) => _reveal()), for (final d in _expanded) _list(d), _loadGit()]);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Connects again after a failed open.
  void _retry() {
    _access?.release();
    _access = null;
    _children.clear();
    setState(() => _error = null);
    _connect();
  }

  Future<void> _list(String dir) async {
    final access = _access;
    if (access == null) return;
    setState(() => _loading.add(dir));
    try {
      final entries = await access.fs.list(dir);
      _children[dir] = sortEntries(entries.where((e) => e.name != '.git'), showHidden: true);
    } catch (_) {
      _expanded.remove(dir);
    } finally {
      if (mounted) setState(() => _loading.remove(dir));
    }
  }

  Future<void> _loadGit() async {
    final access = _access;
    if (access == null) return;
    try {
      final result = await access.runner.run(gitStatusCommand(ws.rootPath));
      _git = parseGitStatus(result);
      _operation = _git == null ? null : await _repo?.operation();
    } catch (_) {
      _git = null;
      _operation = null;
    }
    if (mounted) setState(() => _gitLoaded = true);
  }

  Future<void> _refresh() async {
    _children.clear();
    await Future.wait([_list(ws.rootPath), for (final d in _expanded) _list(d), _loadGit()]);
  }

  void _toggle(String dir) {
    setState(() {
      if (!_expanded.remove(dir)) {
        _expanded.add(dir);
        if (!_children.containsKey(dir)) _list(dir);
      }
    });
  }

  void _openFile(String path) {
    _state.lastOpened[ws.id] = path;
    Navigator.of(context).pop();
    ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).viewer(ws.connectionId, path));
  }

  /// The visible rows: folders' children under them while they are open.
  List<(FileEntry, int)> _rows() {
    final out = <(FileEntry, int)>[];
    void add(String dir, int depth) {
      for (final e in _children[dir] ?? const <FileEntry>[]) {
        out.add((e, depth));
        if (e.isBrowsable && _expanded.contains(e.path)) add(e.path, depth + 1);
      }
    }

    add(ws.rootPath, 0);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final host = ref.watch(connectionProvider(ws.connectionId)).value;
    final vcs = _state.versionControl;
    final git = _git;
    final changes = git?.changes.length ?? 0;
    return Column(
      children: [
        _Card(
          title: ws.name,
          subtitle: '${host?.name ?? ''} · ${ws.rootPath}',
          footer: git == null
              ? null
              : Builder(
                  builder: (anchor) => InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _repo == null ? null : () => showBranchMenu(anchor, _repo!, _loadGit),
                    child: Row(
                      children: [
                        Icon(Icons.call_split, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            [
                              git.branch ?? l10n.detachedHead,
                              if (git.ahead > 0) '↑${git.ahead}',
                              if (git.behind > 0) '↓${git.behind}',
                            ].join('  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 20, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
          activity: git == null ? null : GitActivityStrip(activity: _activity),
          menu: (_) => _menu(context),
        ),
        Expanded(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        switch (_error) {
                          final SshConnectException e => sshErrorText(l10n, e),
                          final e => l10n.errorGeneric('$e'),
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.tryAgain),
                        onPressed: _retry,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: vcs
                      ? GitPanel(
                          repo: _repo,
                          status: _git,
                          loaded: _gitLoaded,
                          onRefresh: _loadGit,
                          onOpen: _openFile,
                          operation: _operation,
                          onResolve: (path) => showConflictResolver(
                            context,
                            repo: _repo!,
                            path: path,
                            fs: _access!.fs,
                            refresh: _loadGit,
                          ),
                        )
                      : _tree(context),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l10n.explorer)),
                ButtonSegment(
                  value: true,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(l10n.versionControl, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (changes > 0) ...[
                        const SizedBox(width: 6),
                        Badge(label: Text('$changes'), backgroundColor: scheme.primary, textColor: scheme.onPrimary),
                      ],
                    ],
                  ),
                ),
              ],
              selected: {vcs},
              onSelectionChanged: (v) => setState(() => _state.versionControl = v.single),
            ),
          ),
        ),
      ],
    );
  }

  List<NuxMenuItem> _menu(BuildContext context) {
    final l10n = context.l10n;
    final switcher = ref.read(workspaceSwitcherProvider);
    final all = ref.read(workspacesProvider).value ?? const <Workspace>[];
    // The drawer closes first; the finder opens over the tabs.
    void find(Future<void> Function(BuildContext, Workspace) show) {
      Navigator.of(context).pop();
      final root = rootNavigatorKey.currentContext;
      if (root != null) show(root, ws);
    }

    return [
      NuxMenuAction(
        icon: Icons.terminal,
        label: l10n.openTerminal,
        onSelected: () {
          Navigator.of(context).pop();
          ref
              .read(workspaceProvider)
              .open(ref.read(tabFactoryProvider).terminal(ws.connectionId, directory: ws.rootPath));
        },
      ),
      NuxMenuAction(icon: Icons.search, label: l10n.quickOpen, onSelected: () => find(showQuickOpen)),
      NuxMenuAction(icon: Icons.manage_search, label: l10n.searchInFiles, onSelected: () => find(showSearchInFiles)),
      if (_git != null && _repo != null) ...[
        const NuxMenuDivider(),
        NuxMenuAction(
          icon: Icons.cloud_download_outlined,
          label: l10n.pull,
          onSelected: () => gitPull(context, _repo!, _loadGit),
        ),
        NuxMenuAction(
          icon: Icons.cloud_upload_outlined,
          label: l10n.push,
          onSelected: () => gitPushWithPreview(context, _repo!, _git?.branch, _loadGit),
        ),
        NuxMenuAction(
          icon: Icons.sync,
          label: l10n.fetch,
          onSelected: () => runGit(context, _repo!.fetch, refresh: _loadGit, done: l10n.fetched, repo: _repo),
        ),
        const NuxMenuDivider(),
        NuxMenuAction(icon: Icons.history, label: l10n.history, onSelected: () => showHistory(context, _repo!)),
        NuxMenuAction(
          icon: Icons.terminal,
          label: l10n.gitOutput,
          enabled: _activity.runs.isNotEmpty,
          onSelected: () => showGitOutput(context, _activity),
        ),
        NuxMenuAction(
          icon: Icons.inventory_2_outlined,
          label: l10n.stashChanges,
          enabled: (_git?.changes.isNotEmpty ?? false),
          onSelected: () => stashChanges(context, _repo!, _loadGit),
        ),
        NuxMenuAction(
          icon: Icons.unarchive_outlined,
          label: l10n.stashes,
          onSelected: () => showStashes(context, _repo!, _loadGit),
        ),
        NuxMenuAction(
          icon: Icons.sell_outlined,
          label: l10n.tags,
          onSelected: () => showTags(context, _repo!, _loadGit),
        ),
      ],
      const NuxMenuDivider(),
      NuxMenuSubmenu(
        icon: Icons.swap_horiz,
        label: l10n.switchWorkspace,
        items: [
          for (final w in all)
            NuxMenuAction(icon: null, label: w.name, checked: w.id == ws.id, onSelected: () => switcher.switchTo(w.id)),
          const NuxMenuDivider(),
          NuxMenuAction(icon: Icons.add, label: l10n.newWorkspace, onSelected: () => newWorkspace(context, ref)),
        ],
      ),
      NuxMenuAction(icon: Icons.refresh, label: l10n.refresh, onSelected: _refresh),
      NuxMenuAction(icon: Icons.edit_outlined, label: l10n.rename, onSelected: () => renameWorkspace(context, ref, ws)),
      NuxMenuAction(icon: Icons.close, label: l10n.closeWorkspace, onSelected: () => switcher.switchTo(null)),
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.delete_outline,
        label: l10n.deleteWorkspace,
        onSelected: () => deleteWorkspace(context, ref, ws),
      ),
    ];
  }

  Widget _tree(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = _rows();
    final changedFolders = _git?.changedFolders ?? const <String>{};
    if (rows.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: _loading.isNotEmpty || _access == null
                ? const Center(child: CircularProgressIndicator())
                : Text(l10n.emptyFolder, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemExtent: _rowHeight,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (e, depth) = rows[i];
        final dir = e.isBrowsable;
        final open = _expanded.contains(e.path);
        final change = dir ? null : _git?.changeOf(e.path);
        final color = change == null ? null : changeColor(change.kind, scheme);
        final marked = changedFolders.contains(e.path);
        final selected = e.path == _target;
        return Builder(
          builder: (rowContext) => Material(
            color: selected ? scheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => dir ? _toggle(e.path) : _openFile(e.path),
              onLongPress: () => _entrySheet(e),
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.0 + depth * 14, 0, 10, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: !dir
                          ? null
                          : _loading.contains(e.path)
                          ? const Center(
                              child: SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : AnimatedRotation(
                              turns: open ? .25 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                            ),
                    ),
                    Icon(
                      dir ? (open ? Icons.folder_open : Icons.folder) : Icons.description_outlined,
                      size: 20,
                      color: dir ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color ?? (selected ? scheme.onSecondaryContainer : null),
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (marked)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
                      )
                    else if (change != null)
                      ChangeLetter(change.kind, staged: change.staged),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// A file's or folder's details and what can be done with it (long press in the tree).
  Future<void> _entrySheet(FileEntry e) async {
    final l10n = context.l10n;
    final dir = e.isBrowsable;
    // A file opens in a browser and a terminal at its folder.
    final folder = dir ? e.path : posix.dirname(e.path);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: Icon(fileIcon(e)), title: Text(e.name), subtitle: Text(e.path)),
              EntryDetails(entry: e),
              const Divider(height: 1),
              if (!dir)
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(l10n.open),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(l10n.openInFileBrowser),
                onTap: () => Navigator.pop(context, 'files'),
              ),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: Text(l10n.openTerminalHere),
                onTap: () => Navigator.pop(context, 'terminal'),
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: Text(l10n.copyPath),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
              if (_git != null) ...[
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.history),
                  onTap: () => Navigator.pop(context, 'history'),
                ),
                if (!dir)
                  ListTile(
                    leading: const Icon(Icons.person_search_outlined),
                    title: Text(l10n.blame),
                    onTap: () => Navigator.pop(context, 'blame'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    final factory = ref.read(tabFactoryProvider);
    final tabs = ref.read(workspaceProvider);
    switch (action) {
      case 'open':
        _openFile(e.path);
      case 'files':
        Navigator.of(context).pop();
        tabs.open(factory.files(ws.connectionId, path: folder));
      case 'terminal':
        Navigator.of(context).pop();
        tabs.open(factory.terminal(ws.connectionId, directory: folder));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: e.path));
        if (mounted) showSnack(context, l10n.copied);
      case 'history':
        await showHistory(context, _repo!, path: e.path);
      case 'blame':
        await showBlame(context, _repo!, e.path);
    }
  }
}

/// Asks for a name, a host and a folder, then opens the new workspace.
Future<void> newWorkspace(BuildContext context, WidgetRef ref, {String? connectionId, String? path}) async {
  final l10n = context.l10n;
  final hosts = ref.read(connectionsProvider).value ?? const <Connection>[];
  final name = TextEditingController(text: path == null ? '' : posix.basename(path));
  final folder = TextEditingController(text: path ?? '');
  var host = connectionId ?? hosts.firstOrNull?.id;
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.newWorkspace),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: host,
                decoration: InputDecoration(labelText: l10n.hostField),
                items: [for (final c in hosts) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => host = v),
                validator: (v) => v == null ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: folder,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.folderField, hintText: '/home/me/project'),
                onChanged: (v) {
                  if (name.text.isEmpty || name.text == posix.basename(posix.dirname('$v/x'))) {
                    name.text = posix.basename(v.trim());
                  }
                },
                validator: (v) => (v ?? '').trim().startsWith('/') ? null : l10n.required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.nameField),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.required : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    ),
  );
  if (ok != true || host == null) return;
  final id = await ref
      .read(workspaceRepositoryProvider)
      .create(name: name.text.trim(), connectionId: host!, rootPath: posix.normalize(folder.text.trim()));
  await ref.read(workspaceSwitcherProvider).switchTo(id);
}

Future<void> renameWorkspace(BuildContext context, WidgetRef ref, Workspace ws) async {
  final name = await askText(context, title: context.l10n.rename, label: context.l10n.nameField, initial: ws.name);
  if (name == null || name.trim().isEmpty) return;
  await ref.read(workspaceRepositoryProvider).rename(ws.id, name.trim());
  await ref.read(workspaceSwitcherProvider).refresh();
}

/// Deletes [ws] after asking (its tabs close; files on the host are not touched).
Future<void> deleteWorkspace(BuildContext context, WidgetRef ref, Workspace ws) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteWorkspaceTitle(ws.name)),
      content: Text(l10n.deleteWorkspaceBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(secretStoreProvider).delete(_gitSecretId(ws.id)); // its git credentials go too
  await ref.read(workspaceSwitcherProvider).delete(ws.id);
}

String _gitSecretId(String workspaceId) => 'git:$workspaceId';

/// Credentials remembered for workspace [id] (secret store: `git:<id>`), if any.
Future<GitCredentials?> loadGitCredentials(WidgetRef ref, String id) async {
  final saved = await ref.read(secretStoreProvider).read(_gitSecretId(id));
  if (saved == null) return null;
  final i = saved.indexOf('\n');
  return i < 0 ? null : (username: saved.substring(0, i), password: saved.substring(i + 1));
}

/// Asks for a username and password (or token) for [remote]; remembered for the workspace if asked.
Future<GitCredentials?> askGitCredentials(
  BuildContext context,
  WidgetRef ref,
  Workspace ws,
  String? remote, {
  required bool retry,
}) async {
  if (!context.mounted) return null;
  final l10n = context.l10n;
  final user = TextEditingController();
  final pass = TextEditingController();
  var remember = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.gitSignInTitle(remote ?? l10n.theRemote)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(retry ? l10n.gitSignInWrong : l10n.gitSignInBody),
            const SizedBox(height: 12),
            TextField(
              controller: user,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.usernameField),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: l10n.passwordOrToken),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: remember,
              onChanged: (v) => setState(() => remember = v ?? false),
              title: Text(l10n.rememberForWorkspace),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.signIn)),
        ],
      ),
    ),
  );
  final c = (username: user.text.trim(), password: pass.text);
  user.dispose();
  pass.dispose();
  if (ok != true || c.username.isEmpty) return null;
  final store = ref.read(secretStoreProvider);
  remember
      ? await store.write(_gitSecretId(ws.id), '${c.username}\n${c.password}')
      : await store.delete(_gitSecretId(ws.id));
  return c;
}
