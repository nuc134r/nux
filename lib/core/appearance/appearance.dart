import 'package:flutter/painting.dart';
import 'package:re_highlight/styles/a11y-dark.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/styles/github-dark.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/idea.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:re_highlight/styles/nord.dart';
import 'package:re_highlight/styles/tokyo-night-dark.dart';
import 'package:re_highlight/styles/tokyo-night-light.dart';
import 'package:re_highlight/styles/vs2015.dart';
import 'package:re_highlight/styles/xcode.dart';

/// Monospace families bundled with the app (assets/fonts; OFL, MIT/Bitstream Vera).
const monoFonts = ['JetBrains Mono', 'Fira Code', 'Hack', 'Source Code Pro'];

/// Fonts with ligatures that can be turned off for code that must show every character.
const ligatureFonts = {'JetBrains Mono', 'Fira Code'};

/// Theme ids that follow the app's light or dark mode.
const autoTheme = 'auto';

/// A terminal colour scheme: background, text and the 16 ANSI colours.
class TerminalColors {
  const TerminalColors(
    this.id,
    this.name, {
    required this.dark,
    required this.background,
    required this.foreground,
    required this.ansi,
  });

  final String id;
  final String name;
  final bool dark;
  final Color background;
  final Color foreground;

  /// Black, red, green, yellow, blue, magenta, cyan, white, then the bright ones.
  final List<Color> ansi;
}

List<Color> _hex(List<int> v) => [for (final c in v) Color(0xFF000000 | c)];

final terminalSchemes = [
  TerminalColors(
    'solarized_dark',
    'Solarized Dark',
    dark: true,
    background: const Color(0xFF002B36),
    foreground: const Color(0xFF839496),
    ansi: _hex([
      0x073642,
      0xDC322F,
      0x859900,
      0xB58900,
      0x268BD2,
      0xD33682,
      0x2AA198,
      0xEEE8D5,
      0x002B36,
      0xCB4B16,
      0x586E75,
      0x657B83,
      0x839496,
      0x6C71C4,
      0x93A1A1,
      0xFDF6E3,
    ]),
  ),
  TerminalColors(
    'solarized_light',
    'Solarized Light',
    dark: false,
    background: const Color(0xFFFDF6E3),
    foreground: const Color(0xFF657B83),
    ansi: _hex([
      0x073642,
      0xDC322F,
      0x859900,
      0xB58900,
      0x268BD2,
      0xD33682,
      0x2AA198,
      0xEEE8D5,
      0x002B36,
      0xCB4B16,
      0x586E75,
      0x657B83,
      0x839496,
      0x6C71C4,
      0x93A1A1,
      0xFDF6E3,
    ]),
  ),
  TerminalColors(
    'dracula',
    'Dracula',
    dark: true,
    background: const Color(0xFF282A36),
    foreground: const Color(0xFFF8F8F2),
    ansi: _hex([
      0x21222C,
      0xFF5555,
      0x50FA7B,
      0xF1FA8C,
      0xBD93F9,
      0xFF79C6,
      0x8BE9FD,
      0xF8F8F2,
      0x6272A4,
      0xFF6E6E,
      0x69FF94,
      0xFFFFA5,
      0xD6ACFF,
      0xFF92DF,
      0xA4FFFF,
      0xFFFFFF,
    ]),
  ),
  TerminalColors(
    'one_dark',
    'One Dark',
    dark: true,
    background: const Color(0xFF282C34),
    foreground: const Color(0xFFABB2BF),
    ansi: _hex([
      0x282C34,
      0xE06C75,
      0x98C379,
      0xE5C07B,
      0x61AFEF,
      0xC678DD,
      0x56B6C2,
      0xABB2BF,
      0x5C6370,
      0xE06C75,
      0x98C379,
      0xE5C07B,
      0x61AFEF,
      0xC678DD,
      0x56B6C2,
      0xFFFFFF,
    ]),
  ),
  TerminalColors(
    'gruvbox_dark',
    'Gruvbox Dark',
    dark: true,
    background: const Color(0xFF282828),
    foreground: const Color(0xFFEBDBB2),
    ansi: _hex([
      0x282828,
      0xCC241D,
      0x98971A,
      0xD79921,
      0x458588,
      0xB16286,
      0x689D6A,
      0xA89984,
      0x928374,
      0xFB4934,
      0xB8BB26,
      0xFABD2F,
      0x83A598,
      0xD3869B,
      0x8EC07C,
      0xEBDBB2,
    ]),
  ),
  TerminalColors(
    'nord',
    'Nord',
    dark: true,
    background: const Color(0xFF2E3440),
    foreground: const Color(0xFFD8DEE9),
    ansi: _hex([
      0x3B4252,
      0xBF616A,
      0xA3BE8C,
      0xEBCB8B,
      0x81A1C1,
      0xB48EAD,
      0x88C0D0,
      0xE5E9F0,
      0x4C566A,
      0xBF616A,
      0xA3BE8C,
      0xEBCB8B,
      0x81A1C1,
      0xB48EAD,
      0x8FBCBB,
      0xECEFF4,
    ]),
  ),
  TerminalColors(
    'monokai',
    'Monokai',
    dark: true,
    background: const Color(0xFF272822),
    foreground: const Color(0xFFF8F8F2),
    ansi: _hex([
      0x272822,
      0xF92672,
      0xA6E22E,
      0xF4BF75,
      0x66D9EF,
      0xAE81FF,
      0xA1EFE4,
      0xF8F8F2,
      0x75715E,
      0xF92672,
      0xA6E22E,
      0xF4BF75,
      0x66D9EF,
      0xAE81FF,
      0xA1EFE4,
      0xF9F8F5,
    ]),
  ),
  TerminalColors(
    'tokyo_night',
    'Tokyo Night',
    dark: true,
    background: const Color(0xFF1A1B26),
    foreground: const Color(0xFFC0CAF5),
    ansi: _hex([
      0x15161E,
      0xF7768E,
      0x9ECE6A,
      0xE0AF68,
      0x7AA2F7,
      0xBB9AF7,
      0x7DCFFF,
      0xA9B1D6,
      0x414868,
      0xF7768E,
      0x9ECE6A,
      0xE0AF68,
      0x7AA2F7,
      0xBB9AF7,
      0x7DCFFF,
      0xC0CAF5,
    ]),
  ),
  TerminalColors(
    'github_light',
    'GitHub Light',
    dark: false,
    background: const Color(0xFFFFFFFF),
    foreground: const Color(0xFF24292F),
    ansi: _hex([
      0x24292F,
      0xCF222E,
      0x116329,
      0x4D2D00,
      0x0969DA,
      0x8250DF,
      0x1B7C83,
      0x6E7781,
      0x57606A,
      0xA40E26,
      0x1A7F37,
      0x633C01,
      0x218BFF,
      0xA475F9,
      0x3192AA,
      0x8C959F,
    ]),
  ),
];

TerminalColors? terminalScheme(String? id) => terminalSchemes.where((s) => s.id == id).firstOrNull;

/// An editor syntax theme (highlight.js style).
class EditorTheme {
  const EditorTheme(this.id, this.name, this.styles, {required this.dark});

  final String id;
  final String name;
  final Map<String, TextStyle> styles;
  final bool dark;

  Color? get background => styles['root']?.backgroundColor;
  Color? get foreground => styles['root']?.color;
}

const editorThemes = [
  EditorTheme('atom_one_dark', 'Atom One Dark', atomOneDarkTheme, dark: true),
  EditorTheme('atom_one_light', 'Atom One Light', atomOneLightTheme, dark: false),
  EditorTheme('github', 'GitHub', githubTheme, dark: false),
  EditorTheme('github_dark', 'GitHub Dark', githubDarkTheme, dark: true),
  EditorTheme('monokai', 'Monokai Sublime', monokaiSublimeTheme, dark: true),
  EditorTheme('nord', 'Nord', nordTheme, dark: true),
  EditorTheme('tokyo_night_dark', 'Tokyo Night Dark', tokyoNightDarkTheme, dark: true),
  EditorTheme('tokyo_night_light', 'Tokyo Night Light', tokyoNightLightTheme, dark: false),
  EditorTheme('vs2015', 'Visual Studio Dark', vs2015Theme, dark: true),
  EditorTheme('xcode', 'Xcode', xcodeTheme, dark: false),
  EditorTheme('idea', 'IntelliJ IDEA', ideaTheme, dark: false),
  EditorTheme('a11y_dark', 'A11y Dark', a11YDarkTheme, dark: true),
];

/// The editor theme for [id]; [autoTheme] (or unknown) follows the app: Atom One Dark or Light.
EditorTheme editorTheme(String? id, {required bool appDark}) =>
    editorThemes.where((t) => t.id == id).firstOrNull ?? editorThemes[appDark ? 0 : 1];
