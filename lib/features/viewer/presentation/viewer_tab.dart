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
  Object? _editorSource;

  /// The editor controllers for the loaded text, recreated when the content changes.
  (CodeLineEditingController, CodeFindController) editorFor(Object source, String text) {
    if (_editor == null || !identical(_editorSource, source)) {
      _finder?.dispose();
      _editor?.dispose();
      _editor = CodeLineEditingController.fromText(text);
      _finder = CodeFindController(_editor!);
      _editorSource = source;
    }
    return (_editor!, _finder!);
  }

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId, 'path': path};

  @override
  String get title => posix.basename(path);

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
    return [
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
      TabMenuEntry(icon: Icons.refresh, label: l10n.reload, onSelected: document.load),
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
    _editor?.dispose();
    super.dispose();
  }
}
