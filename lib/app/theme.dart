import 'package:flutter/material.dart';

/// Monospace family bundled with the app (assets/fonts, OFL).
const monoFont = 'JetBrains Mono';

/// For keys, fingerprints and randomart: JetBrains Mono's ligatures would merge `==`, `->` etc.
const noLigatures = [FontFeature.disable('liga'), FontFeature.disable('calt')];

const _seed = Color(0xFF2E7D6B);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // Android's zoom transition, quicker than the default; no back-gesture preview.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: QuickZoomPageTransitionsBuilder(),
        TargetPlatform.windows: QuickZoomPageTransitionsBuilder(),
        TargetPlatform.linux: QuickZoomPageTransitionsBuilder(),
      },
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, scrolledUnderElevation: 2),
    // Floating a little above the bottom edge, swiped away sideways.
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(12, 0, 12, 16),
      dismissDirection: DismissDirection.horizontal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    // Draggable (long lists and files), a bit wider than the default for fingers.
    scrollbarTheme: ScrollbarThemeData(
      interactive: true,
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: .3)),
    ),
  );
}

/// Android's zoom page transition, at 200 ms in and 160 ms out instead of 300.
class QuickZoomPageTransitionsBuilder extends ZoomPageTransitionsBuilder {
  const QuickZoomPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 160);
}
