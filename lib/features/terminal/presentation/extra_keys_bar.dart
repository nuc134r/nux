import 'package:flterm/flterm.dart' as ft;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/keys/key_bar_layout.dart';
import '../../../core/widgets/key_bar.dart';
import '../../settings/data/settings_repository.dart';

/// Keys a phone keyboard lacks (Esc, Tab, Ctrl/Alt, arrows, symbols), laid out by the terminal keys
/// setting. Ctrl and Alt apply to the next key typed (on either keyboard); held, they stay on.
class ExtraKeysBar extends ConsumerStatefulWidget {
  const ExtraKeysBar({super.key, required this.terminal});

  final ft.TerminalController terminal;

  @override
  ConsumerState<ExtraKeysBar> createState() => _ExtraKeysBarState();
}

const _terminalSpecial = {
  'ESC': ft.Key.escape,
  'TAB': ft.Key.tab,
  'LEFT': ft.Key.arrowLeft,
  'UP': ft.Key.arrowUp,
  'DOWN': ft.Key.arrowDown,
  'RIGHT': ft.Key.arrowRight,
  'HOME': ft.Key.home,
  'END': ft.Key.end,
  'PGUP': ft.Key.pageUp,
  'PGDN': ft.Key.pageDown,
  'INS': ft.Key.insert,
  'DEL': ft.Key.delete,
  'BKSP': ft.Key.backspace,
  'ENTER': ft.Key.enter,
  'SPACE': ft.Key.space,
  'F1': ft.Key.f1,
  'F2': ft.Key.f2,
  'F3': ft.Key.f3,
  'F4': ft.Key.f4,
  'F5': ft.Key.f5,
  'F6': ft.Key.f6,
  'F7': ft.Key.f7,
  'F8': ft.Key.f8,
  'F9': ft.Key.f9,
  'F10': ft.Key.f10,
  'F11': ft.Key.f11,
  'F12': ft.Key.f12,
};

/// Whether the terminal can do [token].
bool terminalSupports(String token) =>
    !isSpecialKey(token) || _terminalSpecial.containsKey(token) || token == 'STAB' || isModifierKey(token);

class _ExtraKeysBarState extends ConsumerState<ExtraKeysBar> {
  ft.TerminalController get _t => widget.terminal;

  /// Modifiers held on: put back after each key clears them.
  final _locked = <String>{};

  static ft.Mods _mod(String token) => token == 'CTRL' ? const ft.Mods.ctrl() : const ft.Mods.alt();

  bool _on(String token) => (_t.virtualMods.value & _mod(token).value) != 0;

  @override
  void initState() {
    super.initState();
    _t.addListener(_relock);
  }

  @override
  void didUpdateWidget(ExtraKeysBar old) {
    super.didUpdateWidget(old);
    if (old.terminal != widget.terminal) {
      old.terminal.removeListener(_relock);
      widget.terminal.addListener(_relock);
    }
  }

  @override
  void dispose() {
    _t.removeListener(_relock);
    super.dispose();
  }

  void _relock() {
    if (_locked.isEmpty) return;
    try {
      for (final m in _locked) {
        if (!_on(m)) _t.toggleMod(_mod(m));
      }
    } on StateError {
      // The terminal was closed.
    }
  }

  void _key(String token) {
    if (isModifierKey(token)) {
      if (_locked.remove(token)) {
        if (_on(token)) _t.toggleMod(_mod(token));
      } else {
        _t.toggleMod(_mod(token));
      }
      setState(() {});
      return;
    }
    final key = _terminalSpecial[token];
    if (token == 'STAB') {
      _t.sendKey(ft.Key.tab, mods: const ft.Mods.shift());
    } else if (key != null) {
      _t.sendKey(key, mods: _t.virtualMods);
    } else {
      // A letter with Ctrl/Alt on is a key press (Ctrl+C); other text is typed as is.
      final letter = token.length == 1 ? ft.Key.values.asNameMap()[token.toLowerCase()] : null;
      if (letter != null && !_t.virtualMods.isEmpty) {
        _t.sendKey(letter, mods: _t.virtualMods);
      } else {
        _t.sendText(token);
        _t.clearVirtualMods();
      }
    }
    if (mounted) setState(() {});
  }

  void _lock(String token) {
    _locked.add(token);
    if (!_on(token)) _t.toggleMod(_mod(token));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final layout =
        ref.watch(appSettingsProvider).value?.keyBar(KeyBarFor.terminal) ??
        keyBarLayout(KeyBarFor.terminal, null, null);
    final rows = [
      for (final r in layout)
        if (r.where((k) => terminalSupports(k.main)).isNotEmpty)
          [
            for (final k in r)
              if (terminalSupports(k.main)) k,
          ],
    ];
    return KeyBar(
      rows: rows,
      onKey: _key,
      onLock: _lock,
      latch: (token) => !isModifierKey(token)
          ? KeyLatch.off
          : _locked.contains(token)
          ? KeyLatch.locked
          : _on(token)
          ? KeyLatch.once
          : KeyLatch.off,
    );
  }
}
