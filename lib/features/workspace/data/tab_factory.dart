import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../files/domain/fs_handle.dart';
import '../../files/presentation/files_tab.dart';
import '../../terminal/domain/terminal_tab.dart';
import '../../viewer/presentation/viewer_tab.dart';
import '../domain/nux_tab.dart';
import '../presentation/hosts_tab.dart';

/// Creates tabs. Tabs keep this provider's [Ref] to reach repositories and the SSH pool.
class TabFactory {
  TabFactory(this._ref);

  final Ref _ref;

  HostsTab hosts() => HostsTab();

  /// A shell on [connectionId], starting in [directory] when given.
  TerminalTab terminal(String connectionId, {String? directory}) =>
      TerminalTab(_ref, connectionId: connectionId, directory: directory);

  FilesTab files(String connectionId, {String? path, FsOpener? open}) =>
      FilesTab(_ref, connectionId: connectionId, path: path, open: open ?? openOverride);

  /// [openerId]: the tab that opened the file (Back closes the viewer and returns there).
  ViewerTab viewer(String connectionId, String path, {FsOpener? open, String? openerId}) =>
      ViewerTab(_ref, connectionId: connectionId, path: path, open: open ?? openOverride, openerId: openerId);

  /// Tests and screenshots: files and viewer tabs use this instead of SFTP.
  FsOpener? openOverride;

  /// Recreates a saved tab; null for unknown kinds (e.g. saved by a newer version).
  NuxTab? restore(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final args = (json['args'] as Map?)?.cast<String, Object?>() ?? const {};
    return switch (json['kind']) {
      HostsTab.kindName => HostsTab(),
      TerminalTab.kindName when id != null && args['connectionId'] is String => TerminalTab(
        _ref,
        connectionId: args['connectionId']! as String,
        directory: args['directory'] as String?,
        id: id,
      ),
      FilesTab.kindName when id != null && args['connectionId'] is String => FilesTab(
        _ref,
        connectionId: args['connectionId']! as String,
        path: args['path'] as String?,
        id: id,
      ),
      ViewerTab.kindName when id != null && args['connectionId'] is String && args['path'] is String => ViewerTab(
        _ref,
        connectionId: args['connectionId']! as String,
        path: args['path']! as String,
        id: id,
      ),
      _ => null,
    };
  }
}

final tabFactoryProvider = Provider((ref) => TabFactory(ref));
