import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../workspace/domain/nux_tab.dart';
import '../data/ssh_fs.dart';
import '../domain/file_browser.dart';
import '../domain/file_listing.dart';
import '../domain/fs_handle.dart';
import 'files_view.dart';

/// A file browser on a host (SFTP).
class FilesTab extends NuxTab {
  /// [open] replaces SFTP (tests and screenshots browse a local folder).
  FilesTab(Ref ref, {required this.connectionId, String? path, String? id, FsOpener? open})
      : id = id ?? 'files:${newId()}',
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
  String? get group => connection?.groupName;

  @override
  Color? get color => connection?.color == null ? null : Color(connection!.color!);

  @override
  Widget buildContent(BuildContext context) => FilesView(tab: this);

  @override
  List<Widget> buildActions(BuildContext context) => [FilesActions(tab: this)];

  @override
  List<TabMenuEntry> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final b = browser;
    return [
      TabMenuEntry(icon: Icons.refresh, label: l10n.refresh, onSelected: b.refresh),
      TabMenuEntry(
        icon: b.showHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        label: b.showHidden ? l10n.hideHiddenFiles : l10n.showHiddenFiles,
        onSelected: b.toggleHidden,
      ),
      for (final s in FileSort.values)
        TabMenuEntry(
          icon: s == b.sort ? (b.descending ? Icons.arrow_downward : Icons.arrow_upward) : Icons.sort,
          label: switch (s) {
            FileSort.name => l10n.sortByName,
            FileSort.size => l10n.sortBySize,
            FileSort.modified => l10n.sortByDate,
          },
          onSelected: () => b.setSort(s),
        ),
      if (b.path != null)
        TabMenuEntry(
          icon: Icons.copy,
          label: l10n.copyPath,
          onSelected: () => Clipboard.setData(ClipboardData(text: b.path!)),
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
