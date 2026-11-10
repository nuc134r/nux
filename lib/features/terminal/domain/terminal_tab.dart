import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/keys/key_bar_layout.dart';
import '../../../core/activity/activity_center.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../../l10n/l10n.dart';
import '../presentation/snippets_view.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../../files/presentation/files_tab.dart';
import '../../workspace/data/workspace.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/key_bar_settings.dart';
import '../../workspace/domain/nux_tab.dart';
import '../presentation/terminal_view.dart';
import 'terminal_session.dart';

class TerminalTab extends NuxTab {
  TerminalTab(this._ref, {required this.connectionId, this.directory, String? id})
      : id = id ?? 'terminal:${newId()}',
        session = TerminalSession(
          connectionId: connectionId,
          directory: directory,
          pool: _ref.read(sshPoolProvider),
          prompter: () => _ref.read(sshPrompterProvider),
          connections: _ref.read(connectionRepositoryProvider),
          log: _ref.read(logProvider),
        ) {
    session.addListener(notifyListeners);
    session.addListener(_reportDrop);
  }

  static const kindName = 'terminal';

  TerminalState _lastState = TerminalState.idle;

  /// A connected session that closes on an error (not by Disconnect) is an Activity event.
  void _reportDrop() {
    final before = _lastState;
    _lastState = session.state;
    if (before != TerminalState.connected || session.state != TerminalState.closed || session.error == null) return;
    final l10n = currentL10n.value;
    _ref.read(activityCenterProvider).event(
      ActivitySource.ssh,
      l10n.activityDisconnected(title),
      subtitle: sshErrorText(l10n, session.error!),
      state: ActivityState.failed,
      retry: session.connect,
    );
  }

  @override
  final String id;

  final Ref _ref;
  final String connectionId;

  /// Folder the shell starts in (e.g. "Terminal here" from the file browser).
  final String? directory;
  final TerminalSession session;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId, 'directory': ?directory};

  @override
  String get title => session.connection?.name ?? '…';

  @override
  String? get subtitle {
    final remote = session.remoteTitle;
    return remote.isNotEmpty ? remote : session.connection?.address;
  }

  @override
  String? get details => [
    if (session.connection case final c?) '${c.name} · ${c.address}',
    if (session.remoteTitle.isNotEmpty) session.remoteTitle,
    ?directory,
  ].join('\n');

  @override
  IconData get icon => switch (session.state) {
        TerminalState.connecting => Icons.sync,
        TerminalState.closed => Icons.link_off,
        _ => Icons.terminal,
      };


  @override
  Color? get color => session.connection?.color == null ? null : Color(session.connection!.color!);

  @override
  Widget buildContent(BuildContext context) => TerminalTabView(tab: this);

  @override
  TextSizeKind? get textSizeKind => TextSizeKind.terminal;

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final connected = session.state == TerminalState.connected;
    return [
      NuxMenuAction(
        icon: Icons.folder_outlined,
        label: l10n.browseFiles,
        // Built directly: this tab's ref belongs to the tab factory, which cannot read itself.
        onSelected: () => _ref.read(workspaceProvider).open(FilesTab(_ref, connectionId: connectionId)),
      ),
      NuxMenuAction(
        icon: Icons.bolt_outlined,
        label: l10n.snippets,
        enabled: connected,
        onSelected: () => showSnippetsSheet(context, send: session.terminal.sendText),
      ),
      NuxMenuAction(
        icon: Icons.content_paste,
        label: l10n.paste,
        onSelected: () async {
          final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
          if (text != null) session.terminal.paste(text);
        },
      ),
      NuxMenuAction(
        icon: Icons.select_all,
        label: l10n.copyAll,
        onSelected: () {
          session.terminal.selectAll();
          Clipboard.setData(ClipboardData(text: session.terminal.selectedText()));
          session.terminal.clearSelection();
        },
      ),
      if (connected)
        NuxMenuAction(icon: Icons.link_off, label: l10n.disconnect, onSelected: session.disconnect)
      else
        NuxMenuAction(
          icon: Icons.refresh,
          label: l10n.reconnect,
          enabled: session.state != TerminalState.connecting,
          onSelected: session.connect,
        ),
      keyBarMenuItem(context, _ref, KeyBarFor.terminal),
    ];
  }

  @override
  void dispose() {
    session.removeListener(notifyListeners);
    session.dispose();
    super.dispose();
  }
}
