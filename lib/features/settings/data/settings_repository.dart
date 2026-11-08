import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/keys/key_bar_layout.dart';

abstract final class SettingKeys {
  static const themeMode = 'themeMode';
  static const locale = 'locale';
  static const autoUpdateCheck = 'autoUpdateCheck';
  static const betaUpdates = 'betaUpdates';
  static const dismissedUpdate = 'dismissedUpdate';
  static const terminalFontSize = 'terminalFontSize';
  static const terminalLineHeight = 'terminalLineHeight';
  static const editorFontSize = 'editorFontSize';
  static const diffSideBySide = 'diffSideBySide';
  static const diffFontSize = 'diffFontSize';
  static const terminalTheme = 'terminalTheme';
  static const terminalFont = 'terminalFont';
  static const editorTheme = 'editorTheme';
  static const editorFont = 'editorFont';
  static const editorLineHeight = 'editorLineHeight';
  static const editorStatusBar = 'editorStatusBar';
  static const terminalKeys = 'terminalKeys';
  static const terminalKeysCustom = 'terminalKeysCustom';
  static const editorKeys = 'editorKeys';
  static const editorKeysCustom = 'editorKeysCustom';

  /// The preset id and custom layout settings of a key bar.
  static (String, String) keyBar(KeyBarFor kind) =>
      kind == KeyBarFor.terminal ? (terminalKeys, terminalKeysCustom) : (editorKeys, editorKeysCustom);
}

/// Text that has its own size setting, changed in Settings, from a tab's menu or by pinching.
enum TextSizeKind {
  terminal(SettingKeys.terminalFontSize, 14),
  editor(SettingKeys.editorFontSize, 13),
  diff(SettingKeys.diffFontSize, 12);

  const TextSizeKind(this.key, this.defaultSize);

  final String key;
  final double defaultSize;

  static const double min = 6;
  static const double max = 32;
}

class AppSettingsState {
  const AppSettingsState(this.values);

  final Map<String, String> values;

  ThemeMode get themeMode => ThemeMode.values.asNameMap()[values[SettingKeys.themeMode]] ?? ThemeMode.system;

  /// Null means "follow the system".
  Locale? get locale => switch (values[SettingKeys.locale]) {
    null || '' => null,
    final code => Locale(code),
  };

  bool get autoUpdateCheck => values[SettingKeys.autoUpdateCheck] != 'false';

  /// Offer pre-releases too.
  bool get betaUpdates => values[SettingKeys.betaUpdates] == 'true';

  double textSize(TextSizeKind kind) =>
      (double.tryParse(values[kind.key] ?? '') ?? kind.defaultSize).clamp(TextSizeKind.min, TextSizeKind.max);

  double get terminalFontSize => textSize(TextSizeKind.terminal);

  double get editorFontSize => textSize(TextSizeKind.editor);

  /// Terminal row height as a multiple of the font's natural line height; denser than the font by default.
  double get terminalLineHeight =>
      (double.tryParse(values[SettingKeys.terminalLineHeight] ?? '') ?? defaultTerminalLineHeight).clamp(.8, 1.6);

  static const defaultTerminalLineHeight = .9;

  /// Terminal colours: a [terminalSchemes] id, or null to follow the app's light or dark mode.
  String? get terminalTheme => values[SettingKeys.terminalTheme];

  /// Editor syntax theme: an [editorThemes] id, or null to follow the app.
  String? get editorTheme => values[SettingKeys.editorTheme];

  String get terminalFont => _font(values[SettingKeys.terminalFont]);

  String get editorFont => _font(values[SettingKeys.editorFont]);

  static String _font(String? f) => monoFonts.contains(f) ? f! : monoFonts.first;

  /// The editor's status bar (cursor, encoding, line endings) is shown.
  bool get editorStatusBar => values[SettingKeys.editorStatusBar] != 'false';

  /// Editor line height as a multiple of the font size.
  double get editorLineHeight =>
      (double.tryParse(values[SettingKeys.editorLineHeight] ?? '') ?? defaultEditorLineHeight).clamp(1.0, 2.0);

  static const defaultEditorLineHeight = 1.3;

  /// Diffs with old and new side by side; null: when the screen is wide enough.
  bool? get diffSideBySide => switch (values[SettingKeys.diffSideBySide]) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  /// The chosen key bar preset id (`custom` for [keyBarCustom]); null: the first preset.
  String? keyBarPreset(KeyBarFor kind) => values[SettingKeys.keyBar(kind).$1];

  String? keyBarCustom(KeyBarFor kind) => values[SettingKeys.keyBar(kind).$2];

  List<List<BarKey>> keyBar(KeyBarFor kind) => keyBarLayout(kind, keyBarPreset(kind), keyBarCustom(kind));

  /// Release version the user chose "Later" for; not offered again.
  String? get dismissedUpdate => values[SettingKeys.dismissedUpdate];
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettingsState> watch() =>
      _db.select(_db.appSettings).watch().map((rows) => AppSettingsState({for (final r in rows) r.key: r.value}));

  Future<AppSettingsState> load() async =>
      AppSettingsState({for (final r in await _db.select(_db.appSettings).get()) r.key: r.value});

  /// Replaces every setting with [values] (a restored backup), keeping those that belong to this device.
  Future<void> replaceAll(Map<String, String> values, {Set<String> keep = const {}}) => _db.transaction(() async {
    await (_db.delete(_db.appSettings)..where((s) => s.key.isNotIn(keep))).go();
    for (final e in values.entries) {
      if (keep.contains(e.key)) continue;
      await _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: e.key, value: e.value));
    }
  });

  Future<void> set(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
    } else {
      await _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
    }
  }
}

final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(appDatabaseProvider)));

extension TextSizeSetting on SettingsRepository {
  Future<void> setTextSize(TextSizeKind kind, double size) =>
      set(kind.key, size.clamp(TextSizeKind.min, TextSizeKind.max).toStringAsFixed(1));
}

final appSettingsProvider = StreamProvider<AppSettingsState>((ref) => ref.watch(settingsRepositoryProvider).watch());
