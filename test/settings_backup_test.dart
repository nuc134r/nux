import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/settings/domain/settings_backup.dart';

void main() {
  test('settings round-trip, without what belongs to this device', () {
    final text = exportSettings({
      'themeMode': 'dark',
      'dismissedUpdate': '1.0.0',
      'terminalFont': 'Hack',
    }, at: DateTime(2026));
    expect(text, isNot(contains('dismissedUpdate')));
    expect(parseSettingsBackup(text), {'themeMode': 'dark', 'terminalFont': 'Hack'});
  });

  test('other files are refused', () {
    for (final t in [
      '',
      'hello',
      '[]',
      '{"app":"other","kind":"settings","version":1,"settings":{}}',
      '{"app":"nux","kind":"settings","version":9,"settings":{}}',
    ]) {
      expect(() => parseSettingsBackup(t), throwsFormatException, reason: t);
    }
  });
}
