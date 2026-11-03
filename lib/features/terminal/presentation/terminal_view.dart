import 'package:flterm/flterm.dart' hide Key;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../domain/terminal_session.dart';
import '../domain/terminal_tab.dart';
import 'extra_keys_bar.dart';

/// The terminal of a [TerminalTab]: starts the shell the first time it is shown.
class TerminalTabView extends ConsumerStatefulWidget {
  const TerminalTabView({super.key, required this.tab});

  final TerminalTab tab;

  @override
  ConsumerState<TerminalTabView> createState() => _TerminalTabViewState();
}

class _TerminalTabViewState extends ConsumerState<TerminalTabView> {
  TerminalSession get _session => widget.tab.session;

  @override
  void initState() {
    super.initState();
    // Restored tabs connect lazily, when first shown (like a browser reloading a tab).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _session.state == TerminalState.idle) _session.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _session.strings = TerminalStrings(
      connecting: l10n.terminalConnecting,
      disconnected: l10n.terminalDisconnected,
      pressEnter: l10n.terminalPressEnter,
      failure: (e) => sshErrorText(l10n, e),
    );
    final fontSize = watchTextSize(ref, TextSizeKind.terminal);
    final lineHeight = ref.watch(
      appSettingsProvider.select((s) => s.value?.terminalLineHeight ?? AppSettingsState.defaultTerminalLineHeight),
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = (dark ? TerminalTheme.dark() : TerminalTheme.light()).copyWith(
      fontFamily: 'JetBrains Mono',
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Column(
        children: [
          if (_session.state == TerminalState.closed)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.link_off),
                title: Text(_session.error == null ? l10n.terminalDisconnected : sshErrorText(l10n, _session.error!)),
                trailing: FilledButton.tonal(onPressed: _session.connect, child: Text(l10n.reconnect)),
              ),
            ),
          if (_session.state == TerminalState.connecting) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: PinchTextSize(
              kind: TextSizeKind.terminal,
              child: TerminalView(
                controller: _session.terminal,
                theme: theme,
                autofocus: true,
                linkSettings: LinkSettings(
                  onActivate: (link) {
                    final uri = link.uri;
                    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),
          ),
          ExtraKeysBar(terminal: _session.terminal),
        ],
      ),
    );
  }
}
