import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';
import 'package:re_editor/re_editor.dart';

import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../files/data/files_providers.dart';
import '../../files/data/ssh_fs.dart';
import '../../files/domain/file_listing.dart';
import '../../files/domain/fs_handle.dart';
import '../../files/presentation/transfers_sheet.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../workspace/domain/nux_tab.dart';
import '../domain/remote_document.dart';
import 'viewer_view.dart';

/// Read-only view of a remote file: code, Markdown, images or hex.
class ViewerTab extends NuxTab {
  /// [open] replaces SFTP (tests and screenshots view local files).
  ViewerTab(this._ref, {required this.connectionId, required this.path, String? id, FsOpener? open})
      : id = id ?? 'viewer:${newId()}',
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
  final RemoteDocument document;

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
  bool get hasUnsavedChanges => dirty;

  /// Text to save.
  String? get editedText => _editor?.text;

  void setEditing(bool v) {
    editing = v;
    notifyListeners();
  }

  /// Saves; called by the view, which handles [RemoteChangedException].
  Future<void> save({bool force = false}) async {
    final text = _editor?.text;
    if (text == null) return;
    await document.save(text, force: force);
    dirty = false;
    notifyListeners();
  }

  /// Set by the view: saves with conflict handling and messages.
  Future<void> Function()? onSave;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId, 'path': path};

  @override
  String get title => '${dirty ? '• ' : ''}${posix.basename(path)}';

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
  List<Widget> buildActions(BuildContext context) {
    final l10n = context.l10n;
    final textual = document.kind == FileKind.text || (document.kind == FileKind.markdown && !rendered);
    final canEdit = textual && !document.truncated && document.bytes != null;
    return [
      if (editing)
        IconButton(
          tooltip: l10n.save,
          icon: document.saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(dirty ? Icons.save : Icons.save_outlined),
          onPressed: dirty && !document.saving ? onSave : null,
        )
      else if (canEdit)
        IconButton(tooltip: l10n.edit, icon: const Icon(Icons.edit_outlined), onPressed: () => setEditing(true)),
      if (document.kind == FileKind.markdown)
        IconButton(
          tooltip: rendered ? l10n.showSource : l10n.showRendered,
          icon: Icon(rendered ? Icons.code : Icons.article_outlined),
          onPressed: () => setRendered(!rendered),
        ),
      if (textual)
        IconButton(
          tooltip: l10n.find,
          icon: const Icon(Icons.search),
          onPressed: _finder?.findMode,
        ),
    ];
  }

  @override
  List<TabMenuEntry> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final textual = document.kind == FileKind.text || document.kind == FileKind.markdown;
    return [
      if (editing) ...[
        TabMenuEntry(icon: Icons.undo, label: l10n.undoEdit, enabled: _editor?.canUndo ?? false, onSelected: () => _editor?.undo()),
        TabMenuEntry(icon: Icons.redo, label: l10n.redoEdit, enabled: _editor?.canRedo ?? false, onSelected: () => _editor?.redo()),
        TabMenuEntry(icon: Icons.visibility_outlined, label: l10n.stopEditing, enabled: !dirty, onSelected: () => setEditing(false)),
      ],
      TabMenuEntry(icon: Icons.refresh, label: l10n.reload, enabled: !dirty, onSelected: document.load),
      if (textual)
        TabMenuEntry(icon: Icons.wrap_text, label: wrap ? l10n.noWrap : l10n.wrapLines, onSelected: () => setWrap(!wrap)),
      if (document.kind == FileKind.binary)
        TabMenuEntry(icon: Icons.notes, label: l10n.showAsText, onSelected: document.showAsText),
      TabMenuEntry(icon: Icons.copy, label: l10n.copyPath, onSelected: () => Clipboard.setData(ClipboardData(text: path))),
      TabMenuEntry(
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
