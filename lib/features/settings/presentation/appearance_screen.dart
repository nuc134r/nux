import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../../core/appearance/appearance.dart';
import '../../../core/widgets/nux_menu.dart';
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
              _Dropdown(
                label: l10n.colors,
                options: [
                  _Option(
                    null,
                    l10n.followApp,
                    _Swatch(
                      background: terminalBackground(null, appDark: appDark),
                      accents: [appDark ? Colors.white : Colors.black],
                    ),
                  ),
                  for (final t in terminalSchemes)
                    _Option(
                      t.id,
                      t.name,
                      _Swatch(background: t.background, accents: [t.ansi[1], t.ansi[2], t.ansi[4]]),
                    ),
                ],
                value: s.terminalTheme,
                onChanged: (id) => repo.set(SettingKeys.terminalTheme, id),
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
              _Dropdown(
                label: l10n.colors,
                options: [
                  _Option(
                    null,
                    l10n.followApp,
                    _Swatch(
                      background: Theme.of(context).colorScheme.surface,
                      accents: [Theme.of(context).colorScheme.onSurface],
                    ),
                  ),
                  for (final t in editorThemes)
                    _Option(
                      t.id,
                      t.name,
                      _Swatch(
                        background: t.background ?? (t.dark ? Colors.black : Colors.white),
                        accents: [
                          for (final k in ['keyword', 'string', 'number'])
                            if (t.styles[k]?.color != null) t.styles[k]!.color!,
                        ],
                      ),
                    ),
                ],
                value: s.editorTheme,
                onChanged: (id) => repo.set(SettingKeys.editorTheme, id),
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

class _Option<T> {
  const _Option(this.value, this.name, [this.preview, this.style]);

  final T value;
  final String name;

  /// Drawn before the name (a colour swatch).
  final Widget? preview;

  /// The name in its own style (a font in that font).
  final TextStyle? style;
}

/// A setting as a compact row: its name, then the current choice; tapping opens the choices in a menu
/// (each with its preview).
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.label, required this.options, required this.value, required this.onChanged});

  final String label;
  final List<_Option<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = options.firstWhere((o) => o.value == value, orElse: () => options.first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Expanded(
            flex: 2,
            child: Builder(
              builder: (anchor) => Material(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showNuxMenu(
                    anchor,
                    beside: true,
                    (_) => [
                      for (final o in options)
                        NuxMenuAction(
                          icon: null,
                          leading: o.preview,
                          label: o.name,
                          labelStyle: o.style,
                          checked: o.value == value,
                          onSelected: () => onChanged(o.value),
                        ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        if (current.preview != null) ...[current.preview!, const SizedBox(width: 10)],
                        Expanded(
                          child: Text(
                            current.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.merge(current.style),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A colour scheme in small: its background with a few of its colours as dots.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.background, this.accents = const []});

  final Color background;
  final List<Color> accents;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 22,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in accents.take(3))
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
      ],
    ),
  );
}

class _FontChoice extends StatelessWidget {
  const _FontChoice({required this.label, required this.value, required this.onChanged});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Dropdown<String>(
    label: label,
    options: [for (final f in monoFonts) _Option(f, f, null, TextStyle(fontFamily: f))],
    value: value,
    onChanged: onChanged,
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
    // The title and value on one line, the slider under them across the whole width.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              Text(label(v)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Slider(
              padding: EdgeInsets.zero,
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
