import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';

abstract final class SettingKeys {
  static const themeMode = 'themeMode';
  static const locale = 'locale';
  static const predictiveBack = 'predictiveBack';
  static const autoUpdateCheck = 'autoUpdateCheck';
  static const betaUpdates = 'betaUpdates';
  static const dismissedUpdate = 'dismissedUpdate';
  static const terminalFontSize = 'terminalFontSize';
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

  /// Android back-swipe animation that previews the previous page; off until turned on.
  bool get predictiveBack => values[SettingKeys.predictiveBack] == 'true';

  bool get autoUpdateCheck => values[SettingKeys.autoUpdateCheck] != 'false';

  /// Offer pre-releases too.
  bool get betaUpdates => values[SettingKeys.betaUpdates] == 'true';

  double get terminalFontSize => (double.tryParse(values[SettingKeys.terminalFontSize] ?? '') ?? 14).clamp(8, 32);

  /// Release version the user chose "Later" for; not offered again.
  String? get dismissedUpdate => values[SettingKeys.dismissedUpdate];
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettingsState> watch() => _db
      .select(_db.appSettings)
      .watch()
      .map((rows) => AppSettingsState({for (final r in rows) r.key: r.value}));

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

final appSettingsProvider = StreamProvider<AppSettingsState>((ref) => ref.watch(settingsRepositoryProvider).watch());
