/// App settings as a file: export to keep or move to another device, restore from it.
library;

import 'dart:convert';

/// Settings that belong to this device and are not exported (an update the user postponed here).
const deviceOnlySettings = {'dismissedUpdate'};

/// [values] as a settings file.
String exportSettings(Map<String, String> values, {required DateTime at}) =>
    const JsonEncoder.withIndent('  ').convert({
      'app': 'nux',
      'kind': 'settings',
      'version': 1,
      'exported': at.toUtc().toIso8601String(),
      'settings': {
        for (final e in values.entries)
          if (!deviceOnlySettings.contains(e.key)) e.key: e.value,
      },
    });

/// The settings in a file made by [exportSettings]. Throws [FormatException] for anything else.
Map<String, String> parseSettingsBackup(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('Not a nux settings file');
  }
  if (json is! Map || json['app'] != 'nux' || json['kind'] != 'settings') {
    throw const FormatException('Not a nux settings file');
  }
  final version = json['version'];
  if (version is! int || version > 1) throw const FormatException('Made by a newer nux');
  final settings = json['settings'];
  if (settings is! Map) throw const FormatException('Not a nux settings file');
  return {
    for (final e in settings.entries)
      if (e.key is String && e.value is String && !deviceOnlySettings.contains(e.key))
        e.key as String: e.value as String,
  };
}
