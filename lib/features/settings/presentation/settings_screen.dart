import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/app_info.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/settings_repository.dart';

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
              SwitchListTile(
                secondary: const Icon(Icons.swipe_left_outlined),
                title: Text(l10n.predictiveBack),
                subtitle: Text(l10n.predictiveBackHint),
                value: settings.predictiveBack,
                onChanged: (v) => repo.set(SettingKeys.predictiveBack, '$v'),
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
