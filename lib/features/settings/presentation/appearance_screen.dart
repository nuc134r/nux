import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/appearance/appearance.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../terminal/presentation/terminal_theme.dart';
import '../data/settings_repository.dart';

/// Terminal and editor: colours, font, size and line spacing, each with a preview.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(appSettingsProvider).value ?? const AppSettingsState({});
    final repo = ref.read(settingsRepositoryProvider);
    final appDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.terminalAndEditor)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Island(
            title: l10n.terminal,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _TerminalPreview(settings: s, appDark: appDark),
              ),
              _Choices(
                label: l10n.colors,
                children: [
                  _Swatch(
                    name: l10n.followApp,
                    background: terminalBackground(null, appDark: appDark),
                    foreground: appDark ? Colors.white : Colors.black,
                    selected: s.terminalTheme == null,
                    onTap: () => repo.set(SettingKeys.terminalTheme, null),
                  ),
                  for (final t in terminalSchemes)
                    _Swatch(
                      name: t.name,
                      background: t.background,
                      foreground: t.foreground,
                      accents: [t.ansi[1], t.ansi[2], t.ansi[4]],
                      selected: s.terminalTheme == t.id,
                      onTap: () => repo.set(SettingKeys.terminalTheme, t.id),
                    ),
                ],
              ),
              _FontChoice(
                label: l10n.font,
                value: s.terminalFont,
                onChanged: (f) => repo.set(SettingKeys.terminalFont, f),
              ),
              _Slider(
                title: l10n.terminalFontSize,
                value: s.terminalFontSize,
                min: TextSizeKind.min,
                max: 24,
                label: (v) => '${v.round()}',
                onChanged: (v) => repo.setTextSize(TextSizeKind.terminal, v.roundToDouble()),
              ),
              _Slider(
                title: l10n.terminalLineSpacing,
                value: s.terminalLineHeight,
                min: .8,
                max: 1.6,
                divisions: 16,
                label: (v) => '${(v * 100).round()}%',
                onChanged: (v) => repo.set(SettingKeys.terminalLineHeight, v.toStringAsFixed(2)),
              ),
            ],
          ),
          Island(
            title: l10n.editor,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _EditorPreview(settings: s, appDark: appDark),
              ),
              _Choices(
                label: l10n.colors,
                children: [
                  _Swatch(
                    name: l10n.followApp,
                    background: Theme.of(context).colorScheme.surface,
                    foreground: Theme.of(context).colorScheme.onSurface,
                    selected: s.editorTheme == null,
                    onTap: () => repo.set(SettingKeys.editorTheme, null),
                  ),
                  for (final t in editorThemes)
                    _Swatch(
                      name: t.name,
                      background: t.background ?? (t.dark ? Colors.black : Colors.white),
                      foreground: t.foreground ?? (t.dark ? Colors.white : Colors.black),
                      accents: [
                        for (final k in ['keyword', 'string', 'number'])
                          if (t.styles[k]?.color != null) t.styles[k]!.color!,
                      ],
                      selected: s.editorTheme == t.id,
                      onTap: () => repo.set(SettingKeys.editorTheme, t.id),
                    ),
                ],
              ),
              _FontChoice(label: l10n.font, value: s.editorFont, onChanged: (f) => repo.set(SettingKeys.editorFont, f)),
              _Slider(
                title: l10n.editorFontSize,
                value: s.editorFontSize,
                min: TextSizeKind.min,
                max: 24,
                label: (v) => '${v.round()}',
                onChanged: (v) => repo.setTextSize(TextSizeKind.editor, v.roundToDouble()),
              ),
              _Slider(
                title: l10n.editorLineSpacing,
                value: s.editorLineHeight,
                min: 1,
                max: 2,
                divisions: 20,
                label: (v) => '${(v * 100).round()}%',
                onChanged: (v) => repo.set(SettingKeys.editorLineHeight, v.toStringAsFixed(2)),
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
        ],
      ),
    );
  }
}

/// A few lines as the terminal would draw them: prompt, a listing in colours, the cursor.
class _TerminalPreview extends StatelessWidget {
  const _TerminalPreview({required this.settings, required this.appDark});

  final AppSettingsState settings;
  final bool appDark;

  @override
  Widget build(BuildContext context) {
    final theme = terminalThemeFor(
      schemeId: settings.terminalTheme,
      appDark: appDark,
      font: settings.terminalFont,
      fontSize: settings.terminalFontSize,
      lineHeight: settings.terminalLineHeight,
    );
    final scheme = terminalScheme(settings.terminalTheme);
    final p = theme.palette;
    Color ansi(int i) => scheme?.ansi[i] ?? p[i];
    final base = TextStyle(
      fontFamily: settings.terminalFont,
      fontSize: settings.terminalFontSize,
      height: settings.terminalLineHeight * 1.2,
      color: p.foreground,
    );
    TextSpan t(String text, [Color? color, bool bold = false]) => TextSpan(
      text: text,
      style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(10)),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            t('user@example', ansi(2), true),
            t(':'),
            t('~/app', ansi(4), true),
            t('\$ ls\n'),
            t('src  ', ansi(4), true),
            t('build.sh  ', ansi(2), true),
            t('notes.md  '),
            t('link', ansi(6), true),
            t('\n'),
            t('error: ', ansi(1), true),
            t('missing '),
            t('"config"', ansi(3)),
            t('\n\$ '),
            TextSpan(
              text: ' ',
              style: TextStyle(backgroundColor: p.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

const _sample = '''import 'dart:io';

/// Says hello.
void main(List<String> args) {
  final name = args.firstOrNull ?? "world";
  for (var i = 0; i < 3; i++) {
    print('Hello, \$name! #\$i');
  }
}''';

final _highlight = Highlight()..registerLanguage('dart', langDart);

class _EditorPreview extends StatelessWidget {
  const _EditorPreview({required this.settings, required this.appDark});

  final AppSettingsState settings;
  final bool appDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = editorTheme(settings.editorTheme, appDark: appDark);
    final follows = settings.editorTheme == null;
    final background = follows ? scheme.surface : (theme.background ?? scheme.surface);
    final base = TextStyle(
      fontFamily: settings.editorFont,
      fontSize: settings.editorFontSize,
      height: settings.editorLineHeight,
      color: follows ? scheme.onSurface : (theme.foreground ?? scheme.onSurface),
    );
    final renderer = TextSpanRenderer(base, theme.styles);
    _highlight.highlight(code: _sample, language: 'dart').render(renderer);
    final lines = _sample.split('\n').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                [for (var i = 1; i <= lines; i++) '$i'].join('\n'),
                textAlign: TextAlign.right,
                style: base.copyWith(color: base.color?.withValues(alpha: .4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text.rich(renderer.span ?? const TextSpan(text: _sample)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label, then choices that wrap.
class _Choices extends StatelessWidget {
  const _Choices({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    ),
  );
}

/// A colour scheme as a small card in its own colours.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.background,
    required this.foreground,
    required this.selected,
    required this.onTap,
    this.accents = const [],
  });

  final String name;
  final Color background;
  final Color foreground;
  final List<Color> accents;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in accents)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              if (accents.isNotEmpty) const SizedBox(width: 2),
              Text(name, style: TextStyle(color: foreground, fontSize: 13)),
              if (selected) ...[const SizedBox(width: 6), Icon(Icons.check, size: 16, color: foreground)],
            ],
          ),
        ),
      ),
    );
  }
}

class _FontChoice extends StatelessWidget {
  const _FontChoice({required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Choices(
    label: label,
    children: [
      for (final f in monoFonts)
        ChoiceChip(
          label: Text(f, style: TextStyle(fontFamily: f)),
          selected: f == value,
          onSelected: (_) => onChanged(f),
        ),
    ],
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
  });

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
          SizedBox(width: 44, child: Text(label(v), textAlign: TextAlign.end)),
          Expanded(
            flex: 2,
            child: Slider(
              value: v,
              min: min,
              max: max,
              divisions: divisions ?? (max - min).round(),
              label: label(v),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
