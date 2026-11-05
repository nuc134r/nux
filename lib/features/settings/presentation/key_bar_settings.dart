import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/keys/key_bar_layout.dart';
import '../../../core/widgets/key_bar.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../../terminal/presentation/extra_keys_bar.dart' show terminalSupports;
import '../../viewer/presentation/viewer_view.dart' show editorSupports;
import '../data/settings_repository.dart';
import 'key_layout_editor.dart';

/// The name of a preset in the UI.
String keyBarPresetName(AppLocalizations l10n, String id) => switch (id) {
  'one_row' => l10n.keysOneRow,
  'two_rows' => l10n.keysTwoRows,
  'two_rows_symbols' => l10n.keysTwoRowsSymbols,
  _ => l10n.keysCustom,
};

/// Pick the terminal's or the editor's extra keys: a preset, or a custom layout written as text.
class KeyBarSettingsScreen extends ConsumerStatefulWidget {
  const KeyBarSettingsScreen({super.key, required this.kind});

  final KeyBarFor kind;

  @override
  ConsumerState<KeyBarSettingsScreen> createState() => _KeyBarSettingsScreenState();
}

class _KeyBarSettingsScreenState extends ConsumerState<KeyBarSettingsScreen> {
  final _custom = TextEditingController();
  bool _loaded = false;
  Timer? _save;

  (String, String) get _keys => SettingKeys.keyBar(widget.kind);

  bool _supports(String token) => widget.kind == KeyBarFor.terminal ? terminalSupports(token) : editorSupports(token);

  List<List<BarKey>> _visible(List<List<BarKey>> rows) => [
    for (final r in rows)
      if (r.any((k) => _supports(k.main)))
        [
          for (final k in r)
            if (_supports(k.main)) k,
        ],
  ];

  @override
  void dispose() {
    _save?.cancel();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _choose(String id) async {
    final repo = ref.read(settingsRepositoryProvider);
    if (id == 'custom' && _custom.text.trim().isEmpty) {
      // Start from what is shown now.
      final settings = ref.read(appSettingsProvider).value;
      _custom.text = formatKeyBar(settings?.keyBar(widget.kind) ?? keyBarLayout(widget.kind, null, null));
      await repo.set(_keys.$2, _custom.text);
    }
    await repo.set(_keys.$1, id);
  }

  /// The custom layout changed (in the editor, or [typed] as text): shown at once, saved a moment later.
  void _setCustom(String text, {bool typed = false}) {
    if (!typed) _custom.text = text;
    setState(() {});
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 400), () => ref.read(settingsRepositoryProvider).set(_keys.$2, text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final presets = keyBarPresets(widget.kind);
    final chosen = settings?.keyBarPreset(widget.kind) ?? presets.first.id;
    if (!_loaded && settings != null) {
      _loaded = true;
      _custom.text = settings.keyBarCustom(widget.kind) ?? '';
    }
    Widget preview(List<List<BarKey>> rows) => IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: KeyBar(rows: _visible(rows), onKey: (_) {}, fit: true),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind == KeyBarFor.terminal ? l10n.terminalKeys : l10n.editorKeys)),
      body: RadioGroup<String>(
        groupValue: chosen,
        onChanged: (v) {
          if (v != null) _choose(v);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final p in presets)
              RadioListTile<String>(
                value: p.id,
                title: Text(keyBarPresetName(l10n, p.id)),
                subtitle: preview(parseKeyBar(p.layout)),
              ),
            RadioListTile<String>(value: 'custom', title: Text(l10n.keysCustom)),
            if (chosen == 'custom') ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: preview(parseKeyBar(_custom.text))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  l10n.keyEditorHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KeyLayoutEditor(
                  rows: parseKeyBar(_custom.text),
                  supports: _supports,
                  onChanged: (rows) => _setCustom(formatKeyBar(rows)),
                ),
              ),
              // The same layout as text, for pasting or sharing one.
              ExpansionTile(
                title: Text(l10n.editAsText),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  TextField(
                    controller: _custom,
                    minLines: 2,
                    maxLines: 6,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(fontFamily: monoFont, fontFeatures: noLigatures),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (text) => _setCustom(text, typed: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l10n.keysCustomHelp(specialKeys.keys.where(_supports).join(' ')),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Extra keys" in a terminal's or editor's menu: the presets, and Customize… (the settings screen).
NuxMenuItem keyBarMenuItem(BuildContext context, Ref ref, KeyBarFor kind) {
  final l10n = context.l10n;
  final settings = ref.read(appSettingsProvider).value;
  final presets = keyBarPresets(kind);
  final chosen = settings?.keyBarPreset(kind) ?? presets.first.id;
  final (presetKey, _) = SettingKeys.keyBar(kind);
  return NuxMenuSubmenu(
    icon: Icons.keyboard_outlined,
    label: l10n.extraKeys,
    hint: keyBarPresetName(l10n, chosen),
    items: [
      for (final p in presets)
        NuxMenuAction(
          icon: null,
          label: keyBarPresetName(l10n, p.id),
          checked: p.id == chosen,
          onSelected: () => ref.read(settingsRepositoryProvider).set(presetKey, p.id),
        ),
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.tune,
        label: l10n.customizeKeys,
        onSelected: () => ref.read(routerProvider).push(Routes.keyBar(kind)),
      ),
    ],
  );
}
