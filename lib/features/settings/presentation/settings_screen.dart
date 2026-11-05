import 'dart:io';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nux_backend/nux_backend.dart' show posix;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/app_info.dart';
import '../../../core/background/background_access.dart';
import '../../../core/log/log.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../core/keys/key_bar_layout.dart';
import '../data/settings_repository.dart';
import '../domain/settings_backup.dart';
import 'key_bar_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettingsState({});
    final repo = ref.read(settingsRepositoryProvider);

    final themeLabels = {
      ThemeMode.system: l10n.themeSystem,
      ThemeMode.light: l10n.themeLight,
      ThemeMode.dark: l10n.themeDark,
    };
    final localeLabels = {'': l10n.languageSystem, 'en': 'English', 'ru': 'Русский'};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Island(
            title: l10n.appearance,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l10n.theme),
                subtitle: Text(themeLabels[settings.themeMode]!),
                onTap: () async {
                  final mode = await _choose(context, l10n.theme, themeLabels, settings.themeMode);
                  if (mode != null) await repo.set(SettingKeys.themeMode, mode.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.language),
                subtitle: Text(localeLabels[settings.locale?.languageCode ?? '']!),
                onTap: () async {
                  final code = await _choose(context, l10n.language, localeLabels, settings.locale?.languageCode ?? '');
                  if (code != null) await repo.set(SettingKeys.locale, code.isEmpty ? null : code);
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(l10n.terminalAndEditor),
                subtitle: Text(l10n.terminalAndEditorHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.appearance),
              ),
            ],
          ),
          Island(
            title: l10n.ssh,
            children: [
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(l10n.keys),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.keys),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(l10n.knownHosts),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.knownHosts),
              ),
              ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: const Text('ZeroTier'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.zerotier),
              ),
            ],
          ),
          Island(
            title: l10n.extraKeys,
            children: [
              ListTile(
                leading: const Icon(Icons.terminal),
                title: Text(l10n.terminalKeys),
                subtitle: Text(keyBarPresetName(l10n, settings.keyBarPreset(KeyBarFor.terminal) ?? 'one_row')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.keyBar(KeyBarFor.terminal)),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: Text(l10n.editorKeys),
                subtitle: Text(keyBarPresetName(l10n, settings.keyBarPreset(KeyBarFor.editor) ?? 'one_row')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.keyBar(KeyBarFor.editor)),
              ),
            ],
          ),
          const _BackgroundIsland(),
          Island(
            title: l10n.backupSettings,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(l10n.exportSettings),
                subtitle: Text(l10n.exportSettingsHint),
                onTap: () => _exportSettings(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: Text(l10n.restoreSettings),
                onTap: () => _restoreSettings(context, ref),
              ),
            ],
          ),
          Island(
            title: l10n.about,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.appVersion),
                subtitle: Text(displayVersion(ref.watch(appVersionProvider).value) ?? '…'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.version),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(l10n.logTitle),
                subtitle: Text(l10n.logTileHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.log),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l10n.sourceCode),
                subtitle: const Text('github.com/$releasesRepo'),
                onTap: () => launchUrl(Uri.https('github.com', '/$releasesRepo'), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: Text(l10n.licenses),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: displayVersion(ref.read(appVersionProvider).value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shares the settings as a file (to keep it, or to restore it on another device).
Future<void> _exportSettings(BuildContext context, WidgetRef ref) async {
  final values = (await ref.read(settingsRepositoryProvider).load()).values;
  final stamp = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${(await getTemporaryDirectory()).path}/nux-settings-$stamp.json');
  await file.writeAsString(exportSettings(values, at: DateTime.now()));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/json')], fileNameOverrides: [posix.basename(file.path)]),
  );
}

/// Replaces the settings with a picked settings file, after asking.
Future<void> _restoreSettings(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final picked = await FilePicker.pickFiles();
  if (picked.isEmpty || !context.mounted) return;
  final Map<String, String> values;
  try {
    values = parseSettingsBackup(await picked.first.xFile.readAsString());
  } on FormatException {
    if (context.mounted) showSnack(context, l10n.notASettingsFile);
    return;
  } catch (e) {
    if (context.mounted) showSnack(context, l10n.errorGeneric('$e'));
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.restoreSettingsTitle),
      content: Text(l10n.restoreSettingsBody(values.length)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.restore)),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(settingsRepositoryProvider).replaceAll(values, keep: deviceOnlySettings);
  if (context.mounted) showSnack(context, l10n.settingsRestored);
}

Future<T?> _choose<T>(BuildContext context, String title, Map<T, String> options, T current) {
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final MapEntry(:key, :value) in options.entries) RadioListTile<T>(value: key, title: Text(value)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Whether Android lets background connections run and show their notification, with buttons to fix it.
/// Refreshed when the app comes back from Android's settings.
class _BackgroundIsland extends ConsumerStatefulWidget {
  const _BackgroundIsland();

  @override
  ConsumerState<_BackgroundIsland> createState() => _BackgroundIslandState();
}

class _BackgroundIslandState extends ConsumerState<_BackgroundIsland> {
  late final _lifecycle = AppLifecycleListener(onResume: _refresh);
  bool? _notifications;
  bool? _battery;

  @override
  void initState() {
    super.initState();
    _lifecycle; // created now, so it hears the app come back
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final access = ref.read(backgroundAccessProvider);
    final n = await access.notificationsAllowed();
    final b = await access.batteryUnrestricted();
    if (!mounted) return;
    setState(() {
      _notifications = n;
      _battery = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final access = ref.read(backgroundAccessProvider);
    final error = Theme.of(context).colorScheme.error;
    Widget tile({
      required IconData icon,
      required String title,
      required bool? ok,
      required String okText,
      required String badText,
      required Future<void> Function() allow,
    }) => ListTile(
      leading: Icon(icon, color: ok == false ? error : null),
      title: Text(title),
      subtitle: Text(ok == false ? badText : okText),
      trailing: ok == false
          ? FilledButton.tonal(
              onPressed: () async {
                await allow();
                await _refresh();
              },
              child: Text(l10n.allow),
            )
          : null,
    );
    // Everything allowed: one line saying so, not a list of settings to read through.
    if (_notifications == true && _battery == true) {
      return Island(
        title: l10n.backgroundChannel,
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(l10n.backgroundAllSet),
            subtitle: Text(l10n.backgroundAllSetHint),
          ),
        ],
      );
    }
    return Island(
      title: l10n.backgroundChannel,
      children: [
        tile(
          icon: Icons.notifications_outlined,
          title: l10n.notificationsLabel,
          ok: _notifications,
          okText: l10n.notificationsOn,
          badText: l10n.notificationsOff,
          allow: () async {
            if (!await access.allowNotifications() && context.mounted) showSnack(context, l10n.notificationsBlocked);
          },
        ),
        tile(
          icon: Icons.battery_saver_outlined,
          title: l10n.batteryLabel,
          ok: _battery,
          okText: l10n.batteryOn,
          badText: l10n.batteryOff,
          allow: access.allowUnrestrictedBattery,
        ),
      ],
    );
  }
}

/// Shares the log (this and earlier launches, hosts masked) as a text file.
Future<void> shareLog(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final text = ref.read(logProvider).export();
  if (text.isEmpty) return showSnack(context, l10n.logEmpty);
  final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-').substring(0, 19);
  final file = File('${(await getTemporaryDirectory()).path}/nux-log-$stamp.txt');
  await file.writeAsString(text);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/plain')],
      subject: 'nux log',
      fileNameOverrides: [posix.basename(file.path)],
    ),
  );
}
