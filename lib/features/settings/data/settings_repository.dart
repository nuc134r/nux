import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

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
}

/// Text that has its own size setting, changed in Settings, from a tab's menu or by pinching.
enum TextSizeKind {
  terminal(SettingKeys.terminalFontSize, 14),
  editor(SettingKeys.editorFontSize, 13);

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

  /// Diffs with old and new side by side; null: when the screen is wide enough.
  bool? get diffSideBySide => switch (values[SettingKeys.diffSideBySide]) {
    'true' => true,
    'false' => false,
    _ => null,
  };

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
