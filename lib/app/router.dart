import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/connections/presentation/connection_editor_screen.dart';
import '../features/connections/presentation/known_hosts_screen.dart';
import '../features/forwarding/presentation/forward_rule_editor.dart';
import '../features/identities/presentation/generate_key_screen.dart';
import '../features/identities/presentation/identities_screen.dart';
import '../features/identities/presentation/identity_screen.dart';
import '../core/keys/key_bar_layout.dart';
import '../features/settings/presentation/appearance_screen.dart';
import '../features/settings/presentation/key_bar_settings.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/updates/presentation/version_screen.dart';
import '../features/workspace/presentation/workspace_screen.dart';
import '../features/zerotier/presentation/zerotier_screen.dart';

/// The navigator dialogs from background work (SSH prompts) are shown on.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Screens that are not tabs. Terminals, files and other work open as tabs (docs/PLAN.md §5),
/// which are not routes.
abstract final class Routes {
  static const home = '/';
  static const settings = '/settings';
  static const version = '/settings/version';
  static const appearance = '/settings/appearance';
  static String keyBar(KeyBarFor kind) => '/settings/keys/${kind.name}';
  static const newConnection = '/connections/new';
  static String connection(String id) => '/connections/$id';
  static const keys = '/keys';
  static const newKey = '/keys/new';
  static String key(String id) => '/keys/$id';
  static const knownHosts = '/known-hosts';

  /// Forwardings belong to a host: they are listed under it in the hosts tab.
  static String newForward(String connectionId) => '/forwarding/new?connection=$connectionId';
  static String forward(String id) => '/forwarding/$id';
  static const zerotier = '/zerotier';

  /// Every screen, with `sample` ids (the smoke test creates rows with those ids).
  static final all = [
    home,
    settings,
    version,
    appearance,
    keyBar(KeyBarFor.terminal),
    keyBar(KeyBarFor.editor),
    newConnection,
    connection('sample'),
    keys,
    newKey,
    key('sample'),
    knownHosts,
    newForward('sample'),
    forward('sample'),
    zerotier,
  ];
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const WorkspaceScreen()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.version, builder: (context, state) => const VersionScreen()),
      GoRoute(path: Routes.appearance, builder: (context, state) => const AppearanceScreen()),
      GoRoute(
        path: '/settings/keys/:kind',
        builder: (context, state) => KeyBarSettingsScreen(kind: KeyBarFor.values.byName(state.pathParameters['kind']!)),
      ),
      GoRoute(path: Routes.newConnection, builder: (context, state) => const ConnectionEditorScreen()),
      GoRoute(
        path: '/connections/:id',
        builder: (context, state) => ConnectionEditorScreen(connectionId: state.pathParameters['id']),
      ),
      GoRoute(path: Routes.keys, builder: (context, state) => const IdentitiesScreen()),
      GoRoute(path: Routes.newKey, builder: (context, state) => const GenerateKeyScreen()),
      GoRoute(
        path: '/keys/:id',
        builder: (context, state) => IdentityScreen(identityId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.knownHosts, builder: (context, state) => const KnownHostsScreen()),
      GoRoute(
        path: '/forwarding/new',
        builder: (context, state) => ForwardRuleEditor(connectionId: state.uri.queryParameters['connection']!),
      ),
      GoRoute(
        path: '/forwarding/:id',
        builder: (context, state) => ForwardRuleEditor(ruleId: state.pathParameters['id']),
      ),
      GoRoute(path: Routes.zerotier, builder: (context, state) => const ZeroTierScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
