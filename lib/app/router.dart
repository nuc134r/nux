import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/updates/presentation/version_screen.dart';

/// Screens that are not tabs. Files, terminals and other work open as tabs (docs/PLAN.md §5),
/// which are not routes.
abstract final class Routes {
  static const home = '/';
  static const settings = '/settings';
  static const version = '/settings/version';

  static const all = [home, settings, version];
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.version, builder: (context, state) => const VersionScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
