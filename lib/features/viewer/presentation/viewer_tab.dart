import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/keys/key_bar_layout.dart';
import '../../settings/presentation/key_bar_settings.dart';
import '../../connections/data/connection_repository.dart';
import '../../workspace/data/workspace_access.dart';
import '../../files/presentation/file_sharing.dart';
import '../../../core/platform/content.dart';
import '../../../core/widgets/widgets.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';
import 'package:re_editor/re_editor.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../files/data/files_providers.dart';
import '../../files/data/ssh_fs.dart';
import '../../files/domain/file_listing.dart';
import '../../files/domain/fs_handle.dart';
import '../../files/presentation/file_dialogs.dart';
import '../../files/presentation/transfers_sheet.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../settings/data/settings_repository.dart';
import '../../workspace/data/workspace.dart';
import '../../workspace/domain/nux_tab.dart';
import '../domain/inspect.dart';
import '../domain/remote_document.dart';
import '../domain/text_encoding.dart';
import 'viewer_view.dart';

/// Read-only view of a remote file: code, Markdown, images or hex.
class ViewerTab extends NuxTab {
  /// [open] replaces SFTP (tests and screenshots view local files).
  ViewerTab(
    this._ref, {
    required this.connectionId,
    required this.path,
    String? id,
    FsOpener? open,
    this.openerId,
    int? line,
    this.content,
  }) : id = id ?? 'viewer:${newId()}',
       pendingLine = line,
       _open = open ?? sshFsOpener(_ref.read(sshPoolProvider), () => _ref.read(sshPrompterProvider), connectionId) {
    document = RemoteDocument(open: _open, path: path);
    document.addListener(notifyListeners);
  }

  static const kindName = 'viewer';

  final Ref _ref;

  @override
  final String id;
  final String connectionId;
  final String path;

  /// The tab that opened this file, if any: Back returns there.
  final String? openerId;
  late final RemoteDocument document;
  final FsOpener _open;

  /// A file another app opened with nux (not on a host): no host actions, not restored after a restart.
  final ContentItem? content;

  /// The connection id of [content] tabs.
  static const contentConnection = 'content';

  /// A line (1-based) to put the cursor on and scroll to once the text is shown (search results).
  int? pendingLine;

  /// View state that outlives the widget (kept while the tab is parked).
  bool wrap = false;
  bool? _rendered;

  /// Markdown and SVG open rendered, HTML as source.
  bool get rendered => _rendered ?? document.kind != FileKind.html;

  /// The bytes instead of what the server describes (an archive's files, a database's tables...).
  bool showBytes = false;

  /// The server's details on a picture or program instead of the picture or bytes.
  bool showDetails = false;

  /// Shows the bytes when a preview cannot be made.
  void showBytesInstead() {
    showBytes = true;
    showDetails = false;
    notifyListeners();
  }

  /// What the server can describe about this file; null for files on no host or that the viewer shows.
  InspectType? get inspectType {
    if (content != null) return null;
    return inspectTypeFor(path) ?? (document.kind == FileKind.binary ? InspectType.executable : null);
  }

  /// Whether the description is shown when the file opens (archives, databases, media, PDFs, pictures
  /// Flutter cannot draw); the rest show it on request ([details]).
  bool get _describedByDefault => switch (inspectType) {
    InspectType.archive || InspectType.database || InspectType.media || InspectType.pdf => true,
    InspectType.image => !drawableImageExt.contains(posix.extension(path).toLowerCase().replaceFirst('.', '')),
    _ => false,
  };

  /// What the view shows instead of the file itself; null shows the file.
  InspectType? get inspecting {
    final type = inspectType;
    if (type == null) return null;
    return (_describedByDefault ? !showBytes : showDetails) ? type : null;
  }

  Future<ArchiveListing>? _listing;

  /// The archive's files, listed once by the server.
  Future<ArchiveListing> listing() =>
      _listing ??= runOnHost(archiveListScript(path)).then((r) => parseArchiveListing(path, r))
        ..catchError((Object _) {
          _listing = null;
          return ArchiveListing('', const []);
        }).ignore();

  Future<List<DetailSection>>? _details;

  /// What the server says about the file (type, media streams, PDF info, ELF header...).
  Future<List<DetailSection>> fileDetails() =>
      _details ??= runOnHost(detailsScript(path, inspectType)).then((r) => parseDetails(r.stdout))
        ..catchError((Object _) {
          _details = null;
          return const <DetailSection>[];
        }).ignore();

  /// An archive operation is running.
  bool busy = false;

  /// The folder shown inside an archive ('' for its top); Back goes up first.
  String archiveDir = '';

  /// The database table shown as rows; Back returns to the tables first.
  String? databaseTable;

  void setArchiveDir(String dir) {
    archiveDir = dir;
    notifyListeners();
  }

  void setDatabaseTable(String? table) {
    databaseTable = table;
    notifyListeners();
  }

  /// Back steps out of a folder of an archive or a table of a database before leaving the file.
  bool get _backInside => switch (inspecting) {
    InspectType.archive => archiveDir.isNotEmpty,
    InspectType.database => databaseTable != null,
    _ => false,
  };

  /// Runs [script] on the file's host.
  Future<CommandResult> runOnHost(String script) async {
    final host = await openHost();
    try {
      return await host.runner.run(script);
    } finally {
      host.release();
    }
  }

  Future<T> _busy<T>(Future<T> Function() work) async {
    busy = true;
    notifyListeners();
    try {
      return await work();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Unpacks [node] into a temporary folder on the host and opens it in a new tab.
  Future<void> openFromArchive(ArchiveListing listing, ArchiveNode node) => _busy(() async {
    final names = listing.tool == 'single' ? const <String>[] : listing.namesUnder(node.path);
    final r = await runOnHost(archiveExtractToTempScript(path, listing.tool, names));
    final dir = r.stdout.trim();
    if (!r.ok || dir.isEmpty) throw InspectException(r.stderr.trim().isEmpty ? 'exit ${r.exitCode}' : r.stderr.trim());
    // On the same host: this tab's way of reading files reads it too.
    _ref
        .read(workspaceProvider)
        .open(ViewerTab(_ref, connectionId: connectionId, path: '$dir/${node.path}', open: _open, openerId: id));
  });

  /// Where [extract] unpacks to: a folder named after the archive next to it (a single compressed file
  /// goes next to it).
  String get extractDestination =>
      inspectTypeFor(path) == InspectType.archive && archiveFormatFor(path) == ArchiveFormat.single
      ? posix.dirname(path)
      : posix.join(posix.dirname(path), archiveStem(path));

  /// Unpacks [node] (everything when null) into [extractDestination]; returns that folder.
  Future<String> extract(ArchiveListing listing, [ArchiveNode? node]) => _busy(() async {
    final names = node == null || listing.tool == 'single' ? const <String>[] : listing.namesUnder(node.path);
    final dest = extractDestination;
    final r = await runOnHost(archiveExtractAllScript(path, listing.tool, dest, names));
    if (!r.ok) throw InspectException(r.stderr.trim().isEmpty ? 'exit ${r.exitCode}' : r.stderr.trim());
    return dest;
  });

  /// Set by the archive view: extracts everything, with progress and a message.
  Future<void> Function()? onExtractAll;

  CodeLineEditingController? _editor;
  CodeFindController? _finder;
  int _editorGeneration = -1;

  /// Edit mode (the file opens read-only).
  bool editing = false;

  /// The text differs from what was loaded or last saved.
  bool dirty = false;

  /// The editor controllers for the loaded text, recreated when the file is (re)loaded, not when saved,
  /// so undo history survives saving.
  (CodeLineEditingController, CodeFindController) editorFor(int generation, String text) {
    if (_editor == null || _editorGeneration != generation) {
      _finder?.dispose();
      _editor?.removeListener(_edited);
      _editor?.dispose();
      _editor = CodeLineEditingController.fromText(text)..addListener(_edited);
      final line = pendingLine;
      if (line != null) {
        final index = (line - 1).clamp(0, _editor!.lineCount - 1);
        _editor!.selection = CodeLineSelection.collapsed(index: index, offset: 0);
      }
      _finder = CodeFindController(_editor!);
      _editorGeneration = generation;
      dirty = false;
    }
    return (_editor!, _finder!);
  }

  void _edited() {
    final now = editing && _editor!.text != document.text;
    if (now != dirty) {
      dirty = now;
      notifyListeners();
    }
  }

  @override
  bool get hasUnsavedChanges => dirty || document.formatChanged;

  /// Text to save.
  String? get editedText => _editor?.text;

  void setEditing(bool v) {
    editing = v;
    notifyListeners();
  }

  /// Leaves edit mode; unsaved changes are saved or discarded after asking. Returns whether edit mode
  /// is off now.
  Future<bool> exitEditing(BuildContext context) async {
    if (!editing) return true;
    if (hasUnsavedChanges) {
      final l10n = context.l10n;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.discardChangesTitle(posix.basename(path))),
          content: Text(l10n.discardChangesBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.keepEditing)),
            TextButton(onPressed: () => Navigator.pop(context, 'discard'), child: Text(l10n.discard)),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: Text(l10n.save)),
          ],
        ),
      );
      switch (choice) {
        case 'save':
          await onSave?.call();
          if (hasUnsavedChanges) return false;
        case 'discard':
          _editorGeneration = -1; // fresh controllers with the loaded text
          dirty = false;
          // A changed encoding or line ending is undone by reading the file again.
          if (document.formatChanged) unawaited(document.load());
        default:
          return false;
      }
    }
    setEditing(false);
    return true;
  }

  /// Whether Back is handled by this tab (rather than leaving the app).
  bool get handlesBack => editing || _backInside || openerId != null;

  /// Back: leaves edit mode, else closes this tab and returns to the tab that opened it.
  Future<void> back(BuildContext context) async {
    if (editing) {
      await exitEditing(context);
      return;
    }
    if (_backInside) {
      if (inspecting == InspectType.archive) {
        setArchiveDir(archiveDir.contains('/') ? archiveDir.substring(0, archiveDir.lastIndexOf('/')) : '');
      } else {
        setDatabaseTable(null);
      }
      return;
    }
    final tabs = _ref.read(workspaceProvider);
    final opener = tabs.tabs.where((t) => t.id == openerId).firstOrNull;
    if (await tabs.close(this) && opener != null) tabs.select(opener);
  }

  /// Asks for a line number and puts the cursor there.
  Future<void> goToLine(BuildContext context) async {
    final editor = _editor;
    if (editor == null) return;
    final l10n = context.l10n;
    final count = editor.lineCount;
    final answer = await askText(
      context,
      title: l10n.goToLine,
      label: l10n.lineField(count),
      validate: (v) {
        final n = int.tryParse(v.trim());
        return n == null || n < 1 || n > count ? l10n.lineField(count) : null;
      },
    );
    final line = int.tryParse(answer?.trim() ?? '');
    if (line == null) return;
    editor.selection = CodeLineSelection.collapsed(index: line - 1, offset: 0);
    editor.makeCursorCenterIfInvisible();
  }

  /// Saves; called by the view, which handles [RemoteChangedException].
  Future<void> save({bool force = false, Future<void> Function(Uint8List data)? writer}) async {
    final text = _editor?.text ?? document.text;
    await document.save(text, force: force, writer: writer);
    dirty = false;
    notifyListeners();
  }

  /// Commands on the file's host (for Save as root), held until released.
  Future<WorkspaceAccess> openHost() => _ref.read(workspaceOpenerProvider)(connectionId);

  /// Set by the view: saves as root (sudo), asking for the password.
  Future<void> Function()? onSaveAsRoot;

  /// Set by the view: saves with conflict handling and messages.
  Future<void> Function()? onSave;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId, 'path': path};

  @override
  String get title => '${hasUnsavedChanges ? '• ' : ''}${posix.basename(path)}';

  @override
  String? get subtitle => content != null ? content!.name : posix.dirname(path);

  @override
  String? get details {
    if (content != null) return content!.name;
    final host = _ref.read(connectionsProvider).value?.where((c) => c.id == connectionId).firstOrNull;
    return host == null ? path : '${host.name}\n$path';
  }

  @override
  IconData get icon => switch (inspectTypeFor(path)) {
    InspectType.archive => Icons.inventory_2_outlined,
    InspectType.database => Icons.table_chart_outlined,
    InspectType.media => Icons.movie_outlined,
    InspectType.pdf => Icons.picture_as_pdf_outlined,
    _ => _kindIcon,
  };

  IconData get _kindIcon => switch (document.kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.markdown => Icons.article_outlined,
    FileKind.svg => Icons.draw_outlined,
    FileKind.html => Icons.html,
    FileKind.archive => Icons.inventory_2_outlined,
    FileKind.binary => Icons.memory,
    FileKind.text => Icons.description_outlined,
  };

  @override
  Widget buildContent(BuildContext context) => ViewerView(tab: this);

  void setWrap(bool v) {
    wrap = v;
    notifyListeners();
  }

  void setRendered(bool v) {
    _rendered = v;
    notifyListeners();
  }

  @override
  // Pictures and hex dumps have no text size to change.
  TextSizeKind? get textSizeKind => document.kind.isTextual && inspecting == null ? TextSizeKind.editor : null;

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final textual = document.kind.isTextual;
    final shownAsText = textual && !(document.kind.renders && rendered);
    final type = inspectType;
    final canEdit = shownAsText && !document.truncated && document.bytes != null;
    final statusBar = _ref.read(appSettingsProvider).value?.editorStatusBar ?? true;
    return [
      if (editing) ...[
        NuxMenuAction(
          icon: Icons.save_outlined,
          label: l10n.save,
          enabled: hasUnsavedChanges && !document.saving,
          onSelected: () => onSave?.call(),
        ),
        if (content == null)
          NuxMenuAction(
            icon: Icons.admin_panel_settings_outlined,
            label: l10n.saveAsRoot,
            enabled: !document.saving,
            onSelected: () => onSaveAsRoot?.call(),
          ),
        NuxMenuAction(icon: Icons.check, label: l10n.doneEditing, onSelected: () => exitEditing(context)),
        // Undo and Redo on one line.
        NuxMenuIcons([
          NuxMenuIcon(
            icon: Icons.undo,
            tooltip: l10n.undoEdit,
            enabled: _editor?.canUndo ?? false,
            onSelected: () => _editor?.undo(),
          ),
          NuxMenuIcon(
            icon: Icons.redo,
            tooltip: l10n.redoEdit,
            enabled: _editor?.canRedo ?? false,
            onSelected: () => _editor?.redo(),
          ),
        ]),
      ] else if (canEdit)
        NuxMenuAction(icon: Icons.edit_outlined, label: l10n.edit, onSelected: () => setEditing(true)),
      if (shownAsText) NuxMenuAction(icon: Icons.search, label: l10n.find, onSelected: () => _finder?.findMode()),
      if (editing)
        NuxMenuAction(icon: Icons.find_replace, label: l10n.replace, onSelected: () => _finder?.replaceMode()),
      if (shownAsText && _editor != null)
        NuxMenuAction(icon: Icons.format_list_numbered, label: l10n.goToLine, onSelected: () => goToLine(context)),
      if (type != null)
        if (_describedByDefault)
          NuxMenuAction(
            icon: showBytes ? Icons.preview_outlined : Icons.memory,
            label: showBytes ? l10n.showPreview : l10n.showBytes,
            onSelected: () {
              showBytes = !showBytes;
              notifyListeners();
            },
          )
        else
          NuxMenuAction(
            icon: Icons.info_outline,
            label: l10n.fileDetails,
            checked: showDetails,
            onSelected: () {
              showDetails = !showDetails;
              notifyListeners();
            },
          ),
      if (inspecting == InspectType.archive)
        NuxMenuAction(
          icon: Icons.unarchive_outlined,
          label: l10n.extractTo('${posix.basename(extractDestination)}/'),
          enabled: !busy,
          onSelected: () => onExtractAll?.call(),
        ),
      if (document.kind.renders && inspecting == null)
        NuxMenuAction(
          icon: rendered ? Icons.code : Icons.article_outlined,
          label: rendered ? l10n.showSource : l10n.showRendered,
          onSelected: () async {
            // The rendered view shows the file, not the editor: leave edit mode first.
            if (!rendered && !await exitEditing(context)) return;
            setRendered(!rendered);
          },
        ),
      if (shownAsText && document.bytes != null) ...[
        const NuxMenuDivider(),
        // How the file is read (only without unsaved edits: they would be lost)...
        NuxMenuSubmenu(
          icon: Icons.translate,
          label: l10n.encoding,
          hint: document.encoding.label,
          items: [
            for (final e in TextEncoding.values)
              NuxMenuAction(
                icon: null,
                label: e.label,
                checked: e == document.encoding,
                enabled: !dirty,
                onSelected: () => document.reopenWith(e),
              ),
          ],
        ),
        // ...and how it is written: both make a save due, so they switch to edit mode.
        if (canEdit || editing) ...[
          NuxMenuSubmenu(
            icon: Icons.save_as_outlined,
            label: l10n.saveWithEncoding,
            items: [
              for (final e in TextEncoding.values)
                NuxMenuAction(
                  icon: null,
                  label: e.label,
                  checked: e == document.encoding,
                  onSelected: () {
                    document.saveAs(e);
                    setEditing(true);
                  },
                ),
            ],
          ),
          NuxMenuSubmenu(
            icon: Icons.keyboard_return,
            label: l10n.lineEndings,
            hint: document.lineEnding.label,
            items: [
              for (final e in LineEnding.values)
                NuxMenuAction(
                  icon: null,
                  label: e.label,
                  checked: e == document.lineEnding,
                  onSelected: () {
                    document.setLineEnding(e);
                    setEditing(true);
                  },
                ),
            ],
          ),
        ],
      ],
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.refresh,
        label: l10n.reload,
        enabled: !hasUnsavedChanges,
        onSelected: () {
          _listing = null;
          _details = null;
          document.load();
        },
      ),
      // How the text is shown: wrapping, the status bar, the keys above the keyboard.
      if (shownAsText)
        NuxMenuSubmenu(
          icon: Icons.visibility_outlined,
          label: l10n.viewMenu,
          items: [
            NuxMenuAction(icon: null, label: l10n.wrapLines, checked: wrap, onSelected: () => setWrap(!wrap)),
            NuxMenuAction(
              icon: null,
              label: l10n.statusBar,
              checked: statusBar,
              onSelected: () => _ref.read(settingsRepositoryProvider).set(SettingKeys.editorStatusBar, '${!statusBar}'),
            ),
            const NuxMenuDivider(),
            keyBarMenuItem(context, _ref, KeyBarFor.editor),
          ],
        )
      else if (textual)
        NuxMenuAction(
          icon: Icons.wrap_text,
          label: wrap ? l10n.noWrap : l10n.wrapLines,
          onSelected: () => setWrap(!wrap),
        ),
      if (document.kind == FileKind.binary && inspecting == null)
        NuxMenuAction(icon: Icons.notes, label: l10n.showAsText, onSelected: document.showAsText),
      NuxMenuAction(
        icon: Icons.share_outlined,
        label: l10n.shareFile,
        onSelected: () async {
          try {
            // What is on screen, unsaved edits included; other files as they are on the host.
            if (textual && (editing || dirty)) {
              await shareText(document.name, _editor?.text ?? document.text);
            } else {
              await shareRemoteFile(_open, path);
            }
          } catch (e) {
            if (context.mounted) showSnack(context, context.l10n.errorGeneric('$e'));
          }
        },
      ),
      if (content == null) ...[
        NuxMenuAction(
          icon: Icons.copy,
          label: l10n.copyPath,
          onSelected: () => Clipboard.setData(ClipboardData(text: path)),
        ),
        NuxMenuAction(
          icon: Icons.download,
          label: l10n.download,
          onSelected: () {
            _ref
                .read(transferManagerProvider)
                .download(connectionId, FileEntry(path: path, type: FileType.file, size: document.size));
            if (context.mounted) showTransfersSheet(context);
          },
        ),
      ],
    ];
  }

  @override
  void dispose() {
    document.removeListener(notifyListeners);
    document.dispose();
    _finder?.dispose();
    _editor?.removeListener(_edited);
    _editor?.dispose();
    super.dispose();
  }
}
