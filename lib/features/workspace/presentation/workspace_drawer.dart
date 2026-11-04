import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../files/domain/file_listing.dart';
import '../../files/presentation/file_dialogs.dart';
import '../data/tab_factory.dart';
import '../data/workspace.dart';
import '../data/workspace_access.dart';
import '../data/workspace_repository.dart';
import '../domain/git_status.dart';
import '../../../app/router.dart';
import 'workspace_find.dart';

/// What the drawer remembers between openings: the side shown and the open folders, per workspace.
class WorkspaceDrawerState {
  bool versionControl = false;
  final Map<String, Set<String>> expanded = {};
}

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
    final all = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final hosts = {for (final c in ref.watch(connectionsProvider).value ?? const <Connection>[]) c.id: c.name};
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Card(
          title: l10n.noWorkspace,
          subtitle: l10n.noWorkspaceHint,
          menu: (_) => [
            NuxMenuAction(icon: Icons.add, label: l10n.newWorkspace, onSelected: () => newWorkspace(context, ref)),
          ],
        ),
        if (all.isNotEmpty) SectionTitle(l10n.workspaces),
        for (final w in all)
          ListTile(
            leading: const Icon(Icons.folder_special_outlined),
            title: Text(w.name),
            subtitle: Text(
              '${hosts[w.connectionId] ?? ''} · ${w.rootPath}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => ref.read(workspaceSwitcherProvider).switchTo(w.id),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: Text(l10n.newWorkspace),
            onPressed: () => newWorkspace(context, ref),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(l10n.noWorkspaceHint, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// The workspace's name, host and folder, and its branch, with ⋮ for switching and managing.
class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, this.footer, required this.menu});

  final String title;
  final String? subtitle;
  final Widget? footer;
  final List<NuxMenuItem> Function(BuildContext) menu;

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
              ],
            ),
          ),
          NuxMenuButton(tooltip: context.l10n.more, items: menu),
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

  Workspace get ws => widget.workspace;
  WorkspaceDrawerState get _state => ref.read(workspaceDrawerStateProvider);
  Set<String> get _expanded => _state.expanded.putIfAbsent(ws.id, () => {});

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _access?.release();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final access = await ref.read(workspaceOpenerProvider)(ws.connectionId);
      if (!mounted) return access.release();
      _access = access;
      await Future.wait([_list(ws.rootPath), for (final d in _expanded) _list(d), _loadGit()]);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
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
    } catch (_) {
      _git = null;
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
              : Row(
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
                  ],
                ),
          menu: (_) => _menu(context),
        ),
        Expanded(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.errorGeneric('$_error'), style: TextStyle(color: scheme.error)),
                )
              : RefreshIndicator(onRefresh: _refresh, child: vcs ? _changesList(context) : _tree(context)),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        SizedBox(
          height: 52,
          child: Row(
            children: [
              _BottomTab(
                label: l10n.explorer,
                selected: !vcs,
                onTap: () => setState(() => _state.versionControl = false),
              ),
              _BottomTab(
                label: l10n.versionControl,
                badge: changes,
                selected: vcs,
                onTap: () => setState(() => _state.versionControl = true),
              ),
            ],
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
      NuxMenuAction(icon: Icons.search, label: l10n.quickOpen, onSelected: () => find(showQuickOpen)),
      NuxMenuAction(icon: Icons.manage_search, label: l10n.searchInFiles, onSelected: () => find(showSearchInFiles)),
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
      NuxMenuAction(icon: Icons.edit_outlined, label: l10n.rename, onSelected: () => _rename(context)),
      NuxMenuAction(icon: Icons.close, label: l10n.closeWorkspace, onSelected: () => switcher.switchTo(null)),
      const NuxMenuDivider(),
      NuxMenuAction(icon: Icons.delete_outline, label: l10n.deleteWorkspace, onSelected: () => _delete(context)),
    ];
  }

  Future<void> _rename(BuildContext context) async {
    final name = await askText(context, title: context.l10n.rename, label: context.l10n.nameField, initial: ws.name);
    if (name == null || name.trim().isEmpty) return;
    await ref.read(workspaceRepositoryProvider).rename(ws.id, name.trim());
    await ref.read(workspaceSwitcherProvider).refresh();
  }

  Future<void> _delete(BuildContext context) async {
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
    if (ok == true) await ref.read(workspaceSwitcherProvider).delete(ws.id);
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
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (e, depth) = rows[i];
        final dir = e.isBrowsable;
        final open = _expanded.contains(e.path);
        final change = dir ? null : _git?.changeOf(e.path);
        final color = change == null ? null : changeColor(change.kind, scheme);
        return Builder(
          builder: (rowContext) => InkWell(
            onTap: () => dir ? _toggle(e.path) : _openFile(e.path),
            onLongPress: dir ? () => _folderMenu(rowContext, e.path) : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.0 + depth * 16, 0, 16, 0),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: dir
                          ? (_loading.contains(e.path)
                                ? const Center(
                                    child: SizedBox.square(
                                      dimension: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Icon(
                                    open ? Icons.expand_more : Icons.chevron_right,
                                    size: 20,
                                    color: scheme.onSurfaceVariant,
                                  ))
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: color ?? (changedFolders.contains(e.path) ? scheme.tertiary : null),
                        ),
                      ),
                    ),
                    if (dir && changedFolders.contains(e.path))
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
                      )
                    else if (change != null)
                      Text(change.kind.letter, style: theme.textTheme.labelLarge?.copyWith(color: color)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _folderMenu(BuildContext rowContext, String path) {
    final l10n = context.l10n;
    showNuxMenu(
      rowContext,
      beside: true,
      (_) => [
        NuxMenuAction(
          icon: Icons.folder_open_outlined,
          label: l10n.openInFileBrowser,
          onSelected: () {
            Navigator.of(context).pop();
            ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).files(ws.connectionId, path: path));
          },
        ),
        NuxMenuAction(
          icon: Icons.terminal,
          label: l10n.openTerminalHere,
          onSelected: () {
            Navigator.of(context).pop();
            ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).terminal(ws.connectionId, directory: path));
          },
        ),
      ],
    );
  }

  Widget _changesList(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final git = _git;
    if (git == null || git.changes.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: !_gitLoaded
                ? const Center(child: CircularProgressIndicator())
                : Text(git == null ? l10n.notGitRepo : l10n.noChanges, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    String relative(String dir) => posix.isWithin(git.root, dir) ? posix.relative(dir, from: git.root) : '';
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: git.changes.length,
      itemBuilder: (context, i) {
        final c = git.changes[i];
        final color = changeColor(c.kind, scheme);
        return ListTile(
          dense: true,
          enabled: c.kind != GitChangeKind.deleted,
          title: Text(
            posix.basename(c.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              decoration: c.kind == GitChangeKind.deleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(relative(posix.dirname(c.path)), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
            c.kind.letter,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: c.staged ? FontWeight.w800 : null),
          ),
          onTap: () => _openFile(c.path),
        );
      },
    );
  }
}

Color changeColor(GitChangeKind kind, ColorScheme scheme) => switch (kind) {
  GitChangeKind.modified => const Color(0xFFE2B93D),
  GitChangeKind.added || GitChangeKind.untracked => const Color(0xFF73C991),
  GitChangeKind.deleted || GitChangeKind.conflict => scheme.error,
  GitChangeKind.renamed => const Color(0xFF6CB6FF),
};

class _BottomTab extends StatelessWidget {
  const _BottomTab({required this.label, required this.selected, required this.onTap, this.badge = 0});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Badge(label: Text('$badge'), backgroundColor: scheme.primary, textColor: scheme.onPrimary),
              ],
            ],
          ),
        ),
      ),
    );
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
