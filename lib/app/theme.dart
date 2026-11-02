import 'package:flutter/material.dart';

/// Monospace family bundled with the app (assets/fonts, OFL).
const monoFont = 'JetBrains Mono';

/// For keys, fingerprints and randomart: JetBrains Mono's ligatures would merge `==`, `->` etc.
const noLigatures = [FontFeature.disable('liga'), FontFeature.disable('calt')];

const _seed = Color(0xFF2E7D6B);

ThemeData buildTheme(Brightness brightness, {bool predictiveBack = false}) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Predictive back on Android is a setting (off by default; the manifest enables the callback).
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android:
            predictiveBack ? const PredictiveBackPageTransitionsBuilder() : const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
      },
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, scrolledUnderElevation: 2),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: .2)),
    ),
  );
}
