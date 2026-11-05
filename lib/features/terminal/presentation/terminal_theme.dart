import 'package:flterm/flterm.dart';
import 'package:flutter/material.dart';

import '../../../core/appearance/appearance.dart';

/// The terminal's theme: the chosen colour scheme (or the default light / dark one), font, size and line height.
TerminalTheme terminalThemeFor({
  required String? schemeId,
  required bool appDark,
  required String font,
  required double fontSize,
  required double lineHeight,
}) {
  final scheme = terminalScheme(schemeId);
  var theme = scheme == null
      ? (appDark ? TerminalTheme.dark() : TerminalTheme.light())
      : (scheme.dark ? TerminalTheme.dark() : TerminalTheme.light()).copyWith(
          palette: ColorPalette(ansiColors: scheme.ansi, background: scheme.background, foreground: scheme.foreground),
        );
  theme = theme.copyWith(fontFamily: font, fontSize: fontSize, lineHeight: lineHeight);
  return theme;
}

/// The background a terminal with [schemeId] shows (for previews).
Color terminalBackground(String? schemeId, {required bool appDark}) => terminalThemeFor(
  schemeId: schemeId,
  appDark: appDark,
  font: monoFonts.first,
  fontSize: 14,
  lineHeight: 1,
).palette.background;
