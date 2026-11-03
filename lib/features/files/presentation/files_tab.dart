import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/widgets/nux_menu.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../terminal/domain/terminal_tab.dart';
import '../../workspace/data/workspace.dart';
import '../../workspace/domain/nux_tab.dart';
import '../data/files_providers.dart';
import '../data/ssh_fs.dart';
import '../domain/file_browser.dart';
import '../domain/file_listing.dart';
import '../domain/fs_handle.dart';
import '../domain/transfers.dart';
import 'files_view.dart';
import 'transfers_sheet.dart';

/// A file browser on a host (SFTP).
class FilesTab extends NuxTab {
  /// [open] replaces SFTP (tests and screenshots browse a local folder).
  FilesTab(Ref ref, {required this.connectionId, String? path, String? id, FsOpener? open})
      : _ref = ref,
        id = id ?? 'files:${newId()}',
        browser = FileBrowser(
          open: open ?? sshFsOpener(ref.read(sshPoolProvider), () => ref.read(sshPrompterProvider), connectionId),
          path: path,
        ) {
    browser.addListener(notifyListeners);
    _sub = ref.read(connectionRepositoryProvider).watch(connectionId).listen((c) {
      connection = c;
      notifyListeners();
    });
  }

  static const kindName = 'files';

  final Ref _ref;
  TransferManager get _transfers => _ref.read(transferManagerProvider);

  @override
  final String id;
  final String connectionId;
  final FileBrowser browser;
  Connection? connection;
  late final StreamSubscription<Connection?> _sub;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId, if (browser.path != null) 'path': browser.path};

  @override
  String get title {
    final p = browser.path;
    if (p == null) return connection?.name ?? '…';
    return p == '/' ? '/' : posix.basename(p);
  }

  @override
  String? get subtitle => connection == null ? browser.path : '${connection!.name} · ${browser.path ?? ''}';

  @override
  IconData get icon => Icons.folder_outlined;


  @override
  Color? get color => connection?.color == null ? null : Color(connection!.color!);

  @override
  Widget buildContent(BuildContext context) => FilesView(tab: this);

  @override
  bool get menuBadge => _transfers.activeCount > 0;

  @override
  Listenable get menuBadgeChanges => _transfers;

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final b = browser;
    String sortName(FileSort s) => switch (s) {
          FileSort.name => l10n.sortName,
          FileSort.size => l10n.sortSize,
          FileSort.modified => l10n.sortModified,
        };
    final transfers = _transfers;
    return [
      NuxMenuAction(
        icon: Icons.terminal,
        label: l10n.openTerminalHere,
        enabled: b.path != null,
        // Built directly: this tab's ref belongs to the tab factory, which cannot read itself.
        onSelected: () => _ref
            .read(workspaceProvider)
            .open(TerminalTab(_ref, connectionId: connectionId, directory: b.path)),
      ),
      NuxMenuAction(
        icon: Icons.create_new_folder_outlined,
        label: l10n.newFolder,
        enabled: b.path != null,
        onSelected: () => createFolder(context, b),
      ),
      NuxMenuAction(
        icon: Icons.upload,
        label: l10n.upload,
        enabled: b.path != null,
        onSelected: () => uploadInto(context, _transfers, connectionId, b),
      ),
      NuxMenuAction(icon: Icons.refresh, label: l10n.refresh, onSelected: b.refresh),
      NuxMenuSubmenu(
        icon: Icons.sort,
        label: l10n.sortMenu,
        hint: sortName(b.sort),
        items: [
          for (final s in FileSort.values)
            NuxMenuAction(icon: null, label: sortName(s), checked: s == b.sort, onSelected: () => b.sortBy(s)),
          const NuxMenuDivider(),
          NuxMenuAction(icon: null, label: l10n.ascending, checked: !b.descending, onSelected: () => b.setDescending(false)),
          NuxMenuAction(icon: null, label: l10n.descending, checked: b.descending, onSelected: () => b.setDescending(true)),
        ],
      ),
      NuxMenuSubmenu(
        icon: Icons.visibility_outlined,
        label: l10n.viewMenu,
        items: [
          NuxMenuAction(
            icon: null,
            label: b.hiddenCount > 0 ? '${l10n.hiddenFiles} (${b.hiddenCount})' : l10n.hiddenFiles,
            checked: b.showHidden,
            onSelected: b.toggleHidden,
          ),
        ],
      ),
      if (b.path != null)
        NuxMenuAction(
          icon: Icons.copy,
          label: l10n.copyPath,
          onSelected: () => Clipboard.setData(ClipboardData(text: b.path!)),
        ),
      if (transfers.transfers.isNotEmpty)
        NuxMenuAction(
          icon: Icons.swap_vert,
          label: l10n.transfers,
          hint: transfers.activeCount > 0 ? l10n.transfersActive(transfers.activeCount) : null,
          onSelected: () => showTransfersSheet(context),
        ),
    ];
  }

  @override
  void dispose() {
    _sub.cancel();
    browser.removeListener(notifyListeners);
    browser.dispose();
    super.dispose();
  }
}
