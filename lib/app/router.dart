import 'package:flutter/material.dart';
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
import '../features/settings/presentation/log_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/terminal/presentation/snippets_view.dart';
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
  static const log = '/settings/log';
  static const snippets = '/settings/snippets';
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
    log,
    snippets,
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

/// A screen as a [MaterialPage], so it opens with the theme's page transition. Left to itself go_router
/// did not recognise the MaterialApp and gave every screen a page without any transition.
GoRoute _screen(String path, Widget Function(GoRouterState state) build) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      MaterialPage<void>(key: state.pageKey, name: state.name ?? state.path, child: build(state)),
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: [
      _screen(Routes.home, (state) => const WorkspaceScreen()),
      _screen(Routes.settings, (state) => const SettingsScreen()),
      _screen(Routes.version, (state) => const VersionScreen()),
      _screen(Routes.appearance, (state) => const AppearanceScreen()),
      _screen(Routes.log, (state) => const LogScreen()),
      _screen(Routes.snippets, (state) => const SnippetsScreen()),
      _screen(
        '/settings/keys/:kind',
        (state) => KeyBarSettingsScreen(kind: KeyBarFor.values.byName(state.pathParameters['kind']!)),
      ),
      _screen(Routes.newConnection, (state) => const ConnectionEditorScreen()),
      _screen('/connections/:id', (state) => ConnectionEditorScreen(connectionId: state.pathParameters['id'])),
      _screen(Routes.keys, (state) => const IdentitiesScreen()),
      _screen(Routes.newKey, (state) => const GenerateKeyScreen()),
      _screen('/keys/:id', (state) => IdentityScreen(identityId: state.pathParameters['id']!)),
      _screen(Routes.knownHosts, (state) => const KnownHostsScreen()),
      _screen('/forwarding/new', (state) => ForwardRuleEditor(connectionId: state.uri.queryParameters['connection']!)),
      _screen('/forwarding/:id', (state) => ForwardRuleEditor(ruleId: state.pathParameters['id'])),
      _screen(Routes.zerotier, (state) => const ZeroTierScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
