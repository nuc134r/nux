import 'package:flterm/flterm.dart' hide Key;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../browser/presentation/open_link.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/presentation/text_size_controls.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../../../core/widgets/widgets.dart';
import '../../files/data/ssh_fs.dart';
import '../../files/presentation/file_dialogs.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../workspace/data/tab_factory.dart';
import '../../workspace/data/workspace.dart';
import '../domain/terminal_paths.dart';
import '../domain/terminal_session.dart';
import '../domain/terminal_tab.dart';
import '../../../core/appearance/appearance.dart';
import 'extra_keys_bar.dart';
import 'terminal_theme.dart';

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
    if (uri != null) await askOpenLink(context, uri);
  }


  @override
  void initState() {
    super.initState();
    // Restored tabs connect lazily, when first shown (like a browser reloading a tab).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _session.state == TerminalState.idle) _session.connect();
    });
  }

  /// Opens a path from the output in an editor tab: relative to the shell's folder when the shell reports
  /// it (OSC 7), else after asking where it is (starting from the home folder).
  Future<void> _openPath(TerminalPath p) async {
    final l10n = context.l10n;
    final connectionId = widget.tab.connectionId;
    final factory = ref.read(tabFactoryProvider);
    final cwd = pwdPath(_session.terminal.pwd);
    String? home;
    if (p.path.startsWith('~') || (!p.path.startsWith('/') && cwd == null)) {
      try {
        final open =
            factory.openOverride ??
            sshFsOpener(ref.read(sshPoolProvider), () => ref.read(sshPrompterProvider), connectionId);
        final handle = await open();
        try {
          home = await handle.fs.home();
        } finally {
          handle.release();
        }
      } catch (e) {
        if (mounted) showSnack(context, l10n.errorGeneric('$e'));
        return;
      }
    }
    var path = resolveTerminalPath(p.path, cwd: cwd, home: home);
    if (path == null) {
      if (!mounted) return;
      path = await askText(
        context,
        title: l10n.openFileAt,
        label: l10n.pathOnServer,
        initial: resolveTerminalPath(p.path, cwd: home ?? widget.tab.directory) ?? p.path,
        confirm: l10n.open,
      );
      if (path == null || path.trim().isEmpty) return;
    }
    _session.terminal.clearSelection();
    ref.read(workspaceProvider).open(factory.viewer(connectionId, path.trim(), line: p.line));
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
    final settings = ref.watch(appSettingsProvider).value;
    final theme = terminalThemeFor(
      schemeId: settings?.terminalTheme,
      appDark: Theme.of(context).brightness == Brightness.dark,
      font: settings?.terminalFont ?? monoFonts.first,
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: PinchTextSize(
                    kind: TextSizeKind.terminal,
                    child: TerminalView(
                      controller: _session.terminal,
                      theme: theme,
                      autofocus: true,
                      linkSettings: _links,
                      // A long press selects a whole path (with its :line), not a piece between slashes.
                      gestureSettings: const TerminalGestureSettings(wordBoundaries: terminalWordBoundaries),
                    ),
                  ),
                ),
                Positioned(top: 8, left: 0, right: 0, child: Center(child: _SelectionBar(terminal: _session.terminal, onOpen: _openPath))),
              ],
            ),
          ),
          ExtraKeysBar(terminal: _session.terminal),
        ],
      ),
    );
  }
}

/// Copy / Paste / Select all while text is selected (long press selects; flterm has no menu of its own).
/// Rebuilds only when the selection appears or goes, not on every output chunk.
class _SelectionBar extends StatefulWidget {
  const _SelectionBar({required this.terminal, required this.onOpen});

  final TerminalController terminal;

  /// The selection is a file path: open it.
  final ValueChanged<TerminalPath> onOpen;

  @override
  State<_SelectionBar> createState() => _SelectionBarState();
}

class _SelectionBarState extends State<_SelectionBar> {
  bool _shown = false;
  TerminalPath? _path;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_changed);
    _shown = widget.terminal.hasSelection;
    if (_shown) _path = parseTerminalPath(widget.terminal.selectedText());
  }

  @override
  void didUpdateWidget(_SelectionBar old) {
    super.didUpdateWidget(old);
    if (old.terminal != widget.terminal) {
      old.terminal.removeListener(_changed);
      widget.terminal.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final now = widget.terminal.hasSelection;
    // While shown, also when the selection grows into (or out of) a path.
    final path = now ? parseTerminalPath(widget.terminal.selectedText()) : null;
    if ((now != _shown || path != _path) && mounted) {
      setState(() {
        _shown = now;
        _path = path;
      });
    }
  }

  Future<void> _copy() async {
    final text = widget.terminal.selectedText();
    widget.terminal.clearSelection();
    if (text.isNotEmpty) await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    widget.terminal.clearSelection();
    if (text != null && text.isNotEmpty) widget.terminal.paste(text);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();
    final labels = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final path = _path;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 4,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (path != null) TextButton(onPressed: () => widget.onOpen(path), child: Text(context.l10n.open)),
            TextButton(onPressed: _copy, child: Text(labels.copyButtonLabel)),
            TextButton(onPressed: _paste, child: Text(labels.pasteButtonLabel)),
            TextButton(onPressed: widget.terminal.selectAll, child: Text(labels.selectAllButtonLabel)),
          ],
        ),
      ),
    );
  }
}
