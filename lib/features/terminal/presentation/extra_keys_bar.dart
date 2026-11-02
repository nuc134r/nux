import 'package:flterm/flterm.dart' as ft;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keys a phone keyboard lacks: Esc, Tab, sticky Ctrl/Alt, arrows, navigation and common symbols.
/// Ctrl and Alt apply to the next key typed (on either keyboard); long-press locks them.
class ExtraKeysBar extends StatefulWidget {
  const ExtraKeysBar({super.key, required this.terminal});

  final ft.TerminalController terminal;

  @override
  State<ExtraKeysBar> createState() => _ExtraKeysBarState();
}

class _ExtraKeysBarState extends State<ExtraKeysBar> {
  ft.TerminalController get _t => widget.terminal;

  void _key(ft.Key key) {
    HapticFeedback.selectionClick();
    _t.sendKey(key, mods: _t.virtualMods);
    _t.clearVirtualMods();
    setState(() {});
  }

  void _text(String s) {
    HapticFeedback.selectionClick();
    _t.sendText(s);
  }

  void _toggle(ft.Mods mod) {
    HapticFeedback.selectionClick();
    _t.toggleMod(mod);
    setState(() {});
  }

  bool _on(ft.Mods mod) => (_t.virtualMods.value & mod.value) != 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, VoidCallback onTap, {bool active = false, String? tooltip}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Material(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Tooltip(
                message: tooltip ?? '',
                triggerMode: TooltipTriggerMode.manual,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w600,
                      color: active ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              key('Esc', () => _key(ft.Key.escape)),
              key('Tab', () => _key(ft.Key.tab)),
              key('Ctrl', () => _toggle(const ft.Mods.ctrl()), active: _on(const ft.Mods.ctrl())),
              key('Alt', () => _toggle(const ft.Mods.alt()), active: _on(const ft.Mods.alt())),
              key('←', () => _key(ft.Key.arrowLeft)),
              key('↑', () => _key(ft.Key.arrowUp)),
              key('↓', () => _key(ft.Key.arrowDown)),
              key('→', () => _key(ft.Key.arrowRight)),
              for (final s in ['|', '~', '/', '-', '_', r'$', '*', '&', '>', '<'])
                key(s, () => _text(s)),
              key('Home', () => _key(ft.Key.home)),
              key('End', () => _key(ft.Key.end)),
              key('PgUp', () => _key(ft.Key.pageUp)),
              key('PgDn', () => _key(ft.Key.pageDown)),
            ],
          ),
        ),
      ),
    );
  }
}
