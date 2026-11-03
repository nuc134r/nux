import 'package:flterm/flterm.dart' hide Key;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Web links are underlined all the time (touch screens have no hover) and open after asking.
  static final _urlRule = LinkRule.regex(
    id: 'url',
    pattern: RegExp(r"""https?://[^\s<>"'`]*[^\s<>"'`.,;:!?)\]}]"""),
    priority: 10,
    highlightMode: LinkHighlightMode.always,
  );
  late final _links = LinkSettings(rules: [_urlRule], onActivate: _openLink);

  Future<void> _openLink(ActivatedLink link) async {
    final uri = link.uri ?? Uri.tryParse(link.text);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.openLinkQuestion),
          content: SelectableText(uri.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uri.toString()));
                Navigator.pop(context, false);
              },
              child: Text(l10n.copy),
            ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.open)),
          ],
        );
      },
    );
    if (open ?? false) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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
                linkSettings: _links,
              ),
            ),
          ),
          ExtraKeysBar(terminal: _session.terminal),
        ],
      ),
    );
  }
}
