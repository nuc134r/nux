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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SubtlePageTransitionsBuilder(),
        TargetPlatform.windows: SubtlePageTransitionsBuilder(),
        TargetPlatform.linux: SubtlePageTransitionsBuilder(),
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

/// Screens fade in while sliding a little from the right, and back out the same way: quick and quiet.
class SubtlePageTransitionsBuilder extends PageTransitionsBuilder {
  const SubtlePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
