import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/log/log.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../workspace/domain/nux_tab.dart';
import '../presentation/terminal_view.dart';
import 'terminal_session.dart';

class TerminalTab extends NuxTab {
  TerminalTab(Ref ref, {required this.connectionId, String? id})
      : id = id ?? 'terminal:${newId()}',
        session = TerminalSession(
          connectionId: connectionId,
          pool: ref.read(sshPoolProvider),
          prompter: () => ref.read(sshPrompterProvider),
          connections: ref.read(connectionRepositoryProvider),
          log: ref.read(logProvider),
        ) {
    session.addListener(notifyListeners);
  }

  static const kindName = 'terminal';

  @override
  final String id;

  final String connectionId;
  final TerminalSession session;

  @override
  String get kind => kindName;

  @override
  Map<String, Object?> get args => {'connectionId': connectionId};

  @override
  String get title => session.connection?.name ?? '…';

  @override
  String? get subtitle {
    final remote = session.remoteTitle;
    return remote.isNotEmpty ? remote : session.connection?.address;
  }

  @override
  IconData get icon => switch (session.state) {
        TerminalState.connecting => Icons.sync,
        TerminalState.closed => Icons.link_off,
        _ => Icons.terminal,
      };

  @override
  String? get group => session.connection?.groupName;

  @override
  Color? get color => session.connection?.color == null ? null : Color(session.connection!.color!);

  @override
  Widget buildContent(BuildContext context) => TerminalTabView(tab: this);

  @override
  List<TabMenuEntry> menuEntries(BuildContext context) {
    final l10n = context.l10n;
    final connected = session.state == TerminalState.connected;
    return [
      TabMenuEntry(
        icon: Icons.content_paste,
        label: l10n.paste,
        onSelected: () async {
          final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
          if (text != null) session.terminal.paste(text);
        },
      ),
      TabMenuEntry(
        icon: Icons.select_all,
        label: l10n.copyAll,
        onSelected: () {
          session.terminal.selectAll();
          Clipboard.setData(ClipboardData(text: session.terminal.selectedText()));
          session.terminal.clearSelection();
        },
      ),
      if (connected)
        TabMenuEntry(icon: Icons.link_off, label: l10n.disconnect, onSelected: session.disconnect)
      else
        TabMenuEntry(
          icon: Icons.refresh,
          label: l10n.reconnect,
          enabled: session.state != TerminalState.connecting,
          onSelected: session.connect,
        ),
    ];
  }

  @override
  void dispose() {
    session.removeListener(notifyListeners);
    session.dispose();
    super.dispose();
  }
}
