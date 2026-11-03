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
                leading: const Icon(Icons.swap_horiz),
                title: Text(l10n.portForwarding),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.forwarding),
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
            title: l10n.text,
            children: [
              _SliderTile(
                icon: Icons.terminal,
                title: l10n.terminalFontSize,
                value: settings.terminalFontSize,
                min: TextSizeKind.min,
                max: 24,
                label: (v) => '${v.round()}',
                onChanged: (v) => repo.setTextSize(TextSizeKind.terminal, v.roundToDouble()),
              ),
              _SliderTile(
                icon: Icons.format_line_spacing,
                title: l10n.terminalLineSpacing,
                value: settings.terminalLineHeight,
                min: .8,
                max: 1.6,
                divisions: 16,
                label: (v) => '${(v * 100).round()}%',
                onChanged: (v) => repo.set(SettingKeys.terminalLineHeight, v.toStringAsFixed(2)),
              ),
              _SliderTile(
                icon: Icons.description_outlined,
                title: l10n.editorFontSize,
                value: settings.editorFontSize,
                min: TextSizeKind.min,
                max: 24,
                label: (v) => '${v.round()}',
                onChanged: (v) => repo.setTextSize(TextSizeKind.editor, v.roundToDouble()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.textSizeHint,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
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

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
  });

  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double v) label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Slider(
        value: v,
        min: min,
        max: max,
        divisions: divisions ?? (max - min).round(),
        label: label(v),
        onChanged: onChanged,
      ),
      trailing: SizedBox(width: 44, child: Text(label(v), textAlign: TextAlign.end)),
    );
  }
}
