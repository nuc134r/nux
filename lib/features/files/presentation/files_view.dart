import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tab_switcher/tab_switcher.dart';
import 'package:intl/intl.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../../workspace/data/tab_factory.dart';
import '../../workspace/data/workspace.dart';
import '../data/bookmark_repository.dart';
import '../data/files_providers.dart';
import '../domain/file_browser.dart';
import '../domain/file_listing.dart';
import '../domain/transfers.dart';
import 'file_dialogs.dart';
import 'files_tab.dart';
import 'transfers_sheet.dart';

/// "5 min ago", "yesterday", "Mar 5", "Mar 5, 2023".
String relativeTime(BuildContext context, DateTime time, {DateTime? now}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final (unit, n) = ageOf(time, now ?? DateTime.now());
  return switch (unit) {
    AgeUnit.justNow => l10n.justNow,
    AgeUnit.minutes => l10n.minutesAgo(n),
    AgeUnit.hours => l10n.hoursAgo(n),
    AgeUnit.yesterday => l10n.yesterday,
    AgeUnit.days => l10n.daysAgo(n),
    AgeUnit.sameYear => DateFormat.MMMd(locale).format(time),
    AgeUnit.olderYear => DateFormat.yMMMd(locale).format(time),
  };
}

/// Text for a file operation error.
String fileErrorText(AppLocalizations l10n, Object e) => switch (e) {
      SshConnectException() => sshErrorText(l10n, e),
      BackendException(:final kind, :final message) => switch (kind) {
          BackendErrorKind.notFound => l10n.fileNotFound,
          BackendErrorKind.permissionDenied => l10n.filePermissionDenied,
          BackendErrorKind.alreadyExists => l10n.fileExists,
          BackendErrorKind.notEmpty => l10n.folderNotEmpty,
          BackendErrorKind.disconnected => l10n.fileDisconnected,
          _ => l10n.errorGeneric(message),
        },
      _ => l10n.errorGeneric('$e'),
    };

IconData fileIcon(FileEntry e) {
  if (e.isBrowsable) return e.type == FileType.link ? Icons.folder_special_outlined : Icons.folder;
  if (e.type == FileType.link) return Icons.link;
  return switch (fileKindByName(e.name)) {
    FileKind.image => Icons.image_outlined,
    FileKind.markdown => Icons.article_outlined,
    FileKind.archive => Icons.inventory_2_outlined,
    FileKind.binary => Icons.memory,
    FileKind.text => Icons.description_outlined,
  };
}

class FilesView extends ConsumerStatefulWidget {
  const FilesView({super.key, required this.tab});

  final FilesTab tab;

  @override
  ConsumerState<FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends ConsumerState<FilesView> {
  FileBrowser get _b => widget.tab.browser;

  @override
  void initState() {
    super.initState();
    if (_b.path == null || _b.entries.isEmpty && _b.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _b.start());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, fileErrorText(context.l10n, e));
    }
  }

  void _open(FileEntry e) {
    if (_b.selecting) return _b.toggleSelected(e);
    if (e.isBrowsable) {
      _b.cd(e.path);
    } else if (fileKindByName(e.name) == FileKind.archive) {
      _entryActions(e);
    } else {
      ref
            .read(workspaceProvider)
            .open(ref.read(tabFactoryProvider).viewer(widget.tab.connectionId, e.path, openerId: widget.tab.id));
    }
  }

  Future<void> _entryActions(FileEntry e) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: Icon(fileIcon(e)), title: Text(e.name), subtitle: Text(e.path)),
              _EntryDetails(entry: e),
              const Divider(height: 1),
              if (!e.isBrowsable) ...[
                ListTile(leading: const Icon(Icons.visibility_outlined), title: Text(l10n.open), onTap: () => Navigator.pop(context, 'open')),
                ListTile(leading: const Icon(Icons.download), title: Text(l10n.download), onTap: () => Navigator.pop(context, 'download')),
              ],
              ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: Text(l10n.rename), onTap: () => Navigator.pop(context, 'rename')),
              ListTile(leading: const Icon(Icons.drive_file_move_outline), title: Text(l10n.moveTo), onTap: () => Navigator.pop(context, 'move')),
              ListTile(leading: const Icon(Icons.lock_outline), title: Text(l10n.permissions), onTap: () => Navigator.pop(context, 'chmod')),
              ListTile(leading: const Icon(Icons.copy), title: Text(l10n.copyPath), onTap: () => Navigator.pop(context, 'copy')),
              if (e.isBrowsable)
                ListTile(leading: const Icon(Icons.terminal), title: Text(l10n.terminalHere), onTap: () => Navigator.pop(context, 'terminal')),
              ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete), onTap: () => Navigator.pop(context, 'delete')),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        ref
            .read(workspaceProvider)
            .open(ref.read(tabFactoryProvider).viewer(widget.tab.connectionId, e.path, openerId: widget.tab.id));
      case 'download':
        _download([e]);
      case 'rename':
        final name = await askText(context,
            title: l10n.rename,
            label: l10n.nameField,
            initial: e.name,
            selectStem: !e.isBrowsable,
            validate: (v) => v.contains('/') ? l10n.invalidFileName : (v != e.name && _b.names.contains(v) ? l10n.fileExists : null));
        if (name != null && name != e.name) await _run(() => _b.rename(e, name));
      case 'move':
        await _move([e.path]);
      case 'chmod':
        final mode = await askPermissions(context, name: e.name, mode: e.mode ?? 0x1a4);
        if (mode != null) await _run(() => _b.chmod(e.path, mode));
      case 'copy':
        await Clipboard.setData(ClipboardData(text: e.path));
        if (mounted) showSnack(context, l10n.copied);
      case 'terminal':
        ref.read(workspaceProvider).open(ref.read(tabFactoryProvider).terminal(widget.tab.connectionId, directory: e.path));
      case 'delete':
        await _delete([e.path]);
    }
  }

  Future<void> _move(List<String> paths) async {
    final l10n = context.l10n;
    final target = await askText(context, title: l10n.moveTo, label: l10n.folderPath, initial: _b.path ?? '/', confirm: l10n.move);
    if (target != null) await _run(() => _b.move(paths, target));
  }

  Future<void> _delete(List<String> paths) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(paths.length == 1 ? l10n.deleteFileTitle(posix.basename(paths.single)) : l10n.deleteFilesTitle(paths.length)),
        content: Text(l10n.deleteFilesBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _b.delete(paths));
  }

  void _download(List<FileEntry> entries) {
    final manager = ref.read(transferManagerProvider);
    final files = entries.where((e) => !e.isBrowsable).toList();
    for (final e in files) {
      manager.download(widget.tab.connectionId, e);
    }
    if (files.length < entries.length) showSnack(context, context.l10n.foldersNotDownloaded);
    showTransfersSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _b,
      builder: (context, _) {
        final entries = _b.entries;
        // Live tabs stay mounted: only the tab in front handles Back.
        final active = TabSwitcher.isActive(context);
        return PopScope(
          canPop: !active || (!_b.selecting && !_b.canGoUp),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !active) return;
            _b.selecting ? _b.clearSelection() : _b.up();
          },
          child: Scaffold(
            bottomNavigationBar: _b.selecting ? _SelectionBar(view: this) : null,
            body: Column(
              children: [
                _Breadcrumbs(tab: widget.tab),
                if (_b.loading) const LinearProgressIndicator(minHeight: 2),
                // The last listing stays visible; say what went wrong above it.
                if (_b.error != null && entries.isNotEmpty) _ErrorBanner(error: _b.error!, onRetry: _b.refresh),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _b.refresh,
                    child: _b.error != null && entries.isEmpty
                        ? ListView(children: [_ErrorView(error: _b.error!, onRetry: _b.refresh)])
                        : entries.isEmpty && !_b.loading && _b.path != null
                            ? ListView(children: [
                                Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    _b.hiddenCount > 0 ? l10n.folderOnlyHidden(_b.hiddenCount) : l10n.folderEmpty,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: entries.length,
                                itemBuilder: (context, i) => _EntryTile(
                                  entry: entries[i],
                                  selecting: _b.selecting,
                                  selected: _b.selection.contains(entries[i].path),
                                  onTap: () => _open(entries[i]),
                                  onLongPress: () => _b.toggleSelected(entries[i]),
                                  onMore: () => _entryActions(entries[i]),
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Picks files on the device and uploads them into the browser's folder.
Future<void> uploadInto(BuildContext context, TransferManager manager, String connectionId, FileBrowser b) async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty || b.path == null || !context.mounted) return;
  for (final f in files) {
    final x = f.xFile;
    final size = await x.length();
    manager.upload(connectionId, b.path!, UploadSource(name: x.name, size: size, open: (start) => x.openRead(start)));
  }
  if (!context.mounted) return;
  showTransfersSheet(context);
  // Show the new files once uploads finish.
  void reloadWhenDone() {
    if (manager.activeCount == 0) {
      manager.removeListener(reloadWhenDone);
      b.refresh();
    }
  }

  manager.addListener(reloadWhenDone);
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.view});

  final _FilesViewState view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = view._b;
    final selected = b.entries.where((e) => b.selection.contains(e.path)).toList();
    return BottomAppBar(
      child: Row(
        children: [
          IconButton(tooltip: l10n.clearSelection, icon: const Icon(Icons.close), onPressed: b.clearSelection),
          Expanded(child: Text(l10n.nSelected(b.selection.length))),
          IconButton(tooltip: l10n.selectAll, icon: const Icon(Icons.select_all), onPressed: b.selectAll),
          IconButton(tooltip: l10n.download, icon: const Icon(Icons.download), onPressed: () => view._download(selected)),
          IconButton(tooltip: l10n.moveTo, icon: const Icon(Icons.drive_file_move_outline), onPressed: () => view._move(b.selection.toList())),
          IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: () => view._delete(b.selection.toList())),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final FileEntry entry;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    final details = [
      if (!e.isBrowsable) formatSize(e.size),
      if (e.modified != null) relativeTime(context, e.modified!),
      ?e.owner,
    ].join(' · ');
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return ListTile(
      selected: selected,
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onTap())
          : Icon(fileIcon(e), size: 22, color: e.isBrowsable ? theme.colorScheme.primary : null),
      title: Text(
        e.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(color: e.isHidden ? theme.colorScheme.onSurfaceVariant : null),
      ),
      subtitle: details.isEmpty ? null : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: selecting
          ? null
          : IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.more,
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onMore,
            ),
    );
  }
}

/// Everything known about an entry, for the top of its actions sheet.
class _EntryDetails extends StatelessWidget {
  const _EntryDetails({required this.entry});

  final FileEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final e = entry;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rows = <(String, String)>[
      if (!e.isBrowsable) (l10n.sizeLabel, '${formatSize(e.size)} (${l10n.bytesCount(NumberFormat.decimalPattern(locale).format(e.size))})'),
      if (e.modified != null) (l10n.modifiedLabel, DateFormat.yMMMd(locale).add_Hms().format(e.modified!)),
      if (e.owner != null) (l10n.ownerLabel, e.group == null ? e.owner! : '${e.owner}:${e.group}'),
      if (e.mode != null) (l10n.permissions, '${permissionString(e.mode!)}  ${e.mode!.toRadixString(8).padLeft(3, '0')}'),
      if (e.linkTarget != null) (l10n.linkTargetLabel, e.linkTarget!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final label = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (k, v) in rows)
            TableRow(children: [
              Padding(padding: const EdgeInsets.only(right: 16, bottom: 4), child: Text(k, style: label)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(v, style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends ConsumerWidget {
  const _Breadcrumbs({required this.tab});

  final FilesTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final b = tab.browser;
    final path = b.path;
    final scheme = Theme.of(context).colorScheme;
    final bookmarks = ref.watch(bookmarksProvider(tab.connectionId)).value ?? const <Bookmark>[];
    final marked = path != null && bookmarks.any((m) => m.path == path);
    final crumbs = path == null ? const <String>[] : pathAncestors(path);
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                reverse: true, // keep the deepest folder in view
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  for (final c in crumbs.reversed) ...[
                    TextButton(
                      onPressed: c == path ? null : () => b.cd(c),
                      child: Text(c == '/' ? '/' : posix.basename(c)),
                    ),
                    if (c != '/') Icon(Icons.chevron_right, size: 16, color: scheme.outline),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.bookmarks,
              icon: Icon(marked ? Icons.bookmark : Icons.bookmark_outline),
              onSelected: (v) async {
                final repo = ref.read(bookmarkRepositoryProvider);
                if (v == '+') {
                  await repo.add(tab.connectionId, path!, path == '/' ? '/' : posix.basename(path));
                } else if (v == '-') {
                  await repo.remove(tab.connectionId, path!);
                } else {
                  await b.cd(v);
                }
              },
              itemBuilder: (context) => [
                if (path != null)
                  PopupMenuItem(
                    value: marked ? '-' : '+',
                    child: ListTile(
                      leading: Icon(marked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
                      title: Text(marked ? l10n.removeBookmark : l10n.bookmarkFolder),
                    ),
                  ),
                if (bookmarks.isNotEmpty) const PopupMenuDivider(),
                for (final m in bookmarks)
                  PopupMenuItem(
                    value: m.path,
                    child: ListTile(leading: const Icon(Icons.folder_outlined), title: Text(m.name), subtitle: Text(m.path)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final lost = error is BackendException && (error as BackendException).kind == BackendErrorKind.disconnected;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(lost ? Icons.link_off : Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(fileErrorText(l10n, error), style: TextStyle(color: scheme.onErrorContainer)),
            ),
            TextButton(onPressed: onRetry, child: Text(lost ? l10n.reconnect : l10n.tryAgain)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(fileErrorText(l10n, error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );
  }
}

/// Asks for a name and creates a folder in the browser's current folder.
Future<void> createFolder(BuildContext context, FileBrowser b) async {
  final l10n = context.l10n;
  final name = await askText(
    context,
    title: l10n.newFolder,
    label: l10n.nameField,
    validate: (v) => v.contains('/') ? l10n.invalidFileName : (b.names.contains(v) ? l10n.fileExists : null),
  );
  if (name == null) return;
  try {
    await b.mkdir(name);
  } catch (e) {
    if (context.mounted) showSnack(context, fileErrorText(l10n, e));
  }
}
