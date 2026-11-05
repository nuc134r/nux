import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/keys/key_bar_layout.dart';
import '../../settings/presentation/key_bar_settings.dart';
import '../../workspace/data/workspace_access.dart';
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
  }) : id = id ?? 'viewer:${newId()}',
       pendingLine = line,
       document = RemoteDocument(
         open: open ?? sshFsOpener(_ref.read(sshPoolProvider), () => _ref.read(sshPrompterProvider), connectionId),
         path: path,
       ) {
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
  final RemoteDocument document;

  /// A line (1-based) to put the cursor on and scroll to once the text is shown (search results).
  int? pendingLine;

  /// View state that outlives the widget (kept while the tab is parked).
  bool wrap = false;
  bool rendered = true;

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
  bool get handlesBack => editing || openerId != null;

  /// Back: leaves edit mode, else closes this tab and returns to the tab that opened it.
  Future<void> back(BuildContext context) async {
    if (editing) {
      await exitEditing(context);
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
  String? get subtitle => posix.dirname(path);

  @override
  IconData get icon => switch (document.kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.markdown => Icons.article_outlined,
    FileKind.binary || FileKind.archive => Icons.memory,
    FileKind.text => Icons.description_outlined,
  };

  @override
  Widget buildContent(BuildContext context) => ViewerView(tab: this);

  void setWrap(bool v) {
    wrap = v;
    notifyListeners();
  }

  void setRendered(bool v) {
    rendered = v;
    notifyListeners();
  }

  @override
  // Pictures and hex dumps have no text size to change.
  TextSizeKind? get textSizeKind =>
      document.kind == FileKind.text || document.kind == FileKind.markdown ? TextSizeKind.editor : null;

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final textual = document.kind == FileKind.text || document.kind == FileKind.markdown;
    final shownAsText = document.kind == FileKind.text || (document.kind == FileKind.markdown && !rendered);
    final canEdit = shownAsText && !document.truncated && document.bytes != null;
    return [
      if (editing) ...[
        NuxMenuAction(
          icon: Icons.save_outlined,
          label: l10n.save,
          enabled: hasUnsavedChanges && !document.saving,
          onSelected: () => onSave?.call(),
        ),
        NuxMenuAction(
          icon: Icons.admin_panel_settings_outlined,
          label: l10n.saveAsRoot,
          enabled: !document.saving,
          onSelected: () => onSaveAsRoot?.call(),
        ),
        NuxMenuAction(icon: Icons.check, label: l10n.doneEditing, onSelected: () => exitEditing(context)),
        NuxMenuAction(
          icon: Icons.undo,
          label: l10n.undoEdit,
          enabled: _editor?.canUndo ?? false,
          onSelected: () => _editor?.undo(),
        ),
        NuxMenuAction(
          icon: Icons.redo,
          label: l10n.redoEdit,
          enabled: _editor?.canRedo ?? false,
          onSelected: () => _editor?.redo(),
        ),
      ] else if (canEdit)
        NuxMenuAction(icon: Icons.edit_outlined, label: l10n.edit, onSelected: () => setEditing(true)),
      if (shownAsText) NuxMenuAction(icon: Icons.search, label: l10n.find, onSelected: () => _finder?.findMode()),
      if (editing)
        NuxMenuAction(icon: Icons.find_replace, label: l10n.replace, onSelected: () => _finder?.replaceMode()),
      if (shownAsText && _editor != null)
        NuxMenuAction(icon: Icons.format_list_numbered, label: l10n.goToLine, onSelected: () => goToLine(context)),
      if (document.kind == FileKind.markdown)
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
      if (editing) keyBarMenuItem(context, _ref, KeyBarFor.editor),
      const NuxMenuDivider(),
      NuxMenuAction(icon: Icons.refresh, label: l10n.reload, enabled: !hasUnsavedChanges, onSelected: document.load),
      if (textual)
        NuxMenuAction(
          icon: Icons.wrap_text,
          label: wrap ? l10n.noWrap : l10n.wrapLines,
          onSelected: () => setWrap(!wrap),
        ),
      if (document.kind == FileKind.binary)
        NuxMenuAction(icon: Icons.notes, label: l10n.showAsText, onSelected: document.showAsText),
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
