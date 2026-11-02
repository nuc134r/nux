import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/secure/secret_store.dart';
import 'package:nux/features/settings/data/settings_repository.dart';

import 'helpers.dart';

void main() {
  test('defaults', () {
    const s = AppSettingsState({});
    expect(s.themeMode, ThemeMode.system);
    expect(s.locale, isNull);
    expect(s.autoUpdateCheck, isTrue);
    expect(s.betaUpdates, isFalse);
  });

  test('settings round-trip through the database', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.set(SettingKeys.themeMode, 'dark');
    await repo.set(SettingKeys.locale, 'ru');
    await repo.set(SettingKeys.betaUpdates, 'true');
    var s = await repo.load();
    expect(s.themeMode, ThemeMode.dark);
    expect(s.locale, const Locale('ru'));
    expect(s.betaUpdates, isTrue);
    await repo.set(SettingKeys.locale, null);
    s = await repo.load();
    expect(s.locale, isNull);
  });

  test('memory secret store lists ids by prefix', () async {
    final store = MemorySecretStore();
    await store.write('key:1', 'a');
    await store.write('key:2', 'b');
    await store.write('password:x', 'c');
    expect(await store.ids(prefix: 'key:'), {'key:1', 'key:2'});
    await store.delete('key:1');
    expect(await store.read('key:1'), isNull);
  });
}
