import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/host_ping.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../ssh/data/ssh_pool.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../forwarding/data/forward_rule_repository.dart';
import '../../forwarding/data/forwarding_providers.dart';
import '../../forwarding/presentation/forwarding_widgets.dart';
import '../data/workspace.dart';
import '../data/workspace_repository.dart';
import '../domain/nux_tab.dart';
import 'workspace_drawer.dart' show deleteWorkspace, newWorkspace, renameWorkspace;

/// Home: the saved hosts and the workspaces, on two pages. There is one at most (opening it again selects
/// it); its kind stays `hosts` so saved sessions restore it.
class HostsTab extends NuxTab {
  HostsTab() {
    currentL10n.addListener(notifyListeners);
  }

  static const kindName = 'hosts';

  @override
  String get id => kindName;

  @override
  String get kind => kindName;

  @override
  String get title => currentL10n.value.home;

  @override
  IconData get icon => Icons.home_outlined;

  /// The page shown: 0 hosts, 1 workspaces (kept while the tab is parked).
  int page = 0;

  /// Hosts whose forwardings are shown.
  final openForwardings = ValueNotifier<Set<String>>(const {});

  void toggleForwardings(String hostId) {
    final open = {...openForwardings.value};
    if (!open.remove(hostId)) open.add(hostId);
    openForwardings.value = open;
  }

  @override
  Widget buildContent(BuildContext context) => _HomeView(tab: this);

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) => [
    NuxMenuAction(icon: Icons.add, label: context.l10n.addHost, onSelected: () => context.push(Routes.newConnection)),
    NuxMenuAction(
      icon: Icons.create_new_folder_outlined,
      label: context.l10n.newWorkspace,
      onSelected: () => _newWorkspace?.call(),
    ),
  ];

  /// Set by the view (it has the WidgetRef the dialog needs).
  VoidCallback? _newWorkspace;

  @override
  void dispose() {
    currentL10n.removeListener(notifyListeners);
    openForwardings.dispose();
    super.dispose();
  }
}

/// Hosts | Workspaces, swiped or picked in the bar.
class _HomeView extends ConsumerStatefulWidget {
  const _HomeView({required this.tab});

  final HostsTab tab;

  @override
  ConsumerState<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<_HomeView> with SingleTickerProviderStateMixin {
  late final TabController _pages;

  @override
  void initState() {
    super.initState();
    _pages = TabController(length: 2, vsync: this, initialIndex: widget.tab.page)
      ..addListener(() => widget.tab.page = _pages.index);
    widget.tab._newWorkspace = () => newWorkspace(context, ref);
  }

  @override
  void dispose() {
    widget.tab._newWorkspace = null;
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        TabBar(
          controller: _pages,
          tabs: [
            Tab(text: l10n.hosts),
            Tab(text: l10n.workspaces),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _pages,
            children: [
              _HostsView(tab: widget.tab),
              const _WorkspacesView(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The workspaces as tiles; tap one for Open / Rename / Delete.
class _WorkspacesView extends ConsumerWidget {
  const _WorkspacesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final hosts = {for (final c in ref.watch(connectionsProvider).value ?? const <Connection>[]) c.id: c.name};
    final switcher = ref.watch(workspaceSwitcherProvider);
    return ListenableBuilder(
      listenable: switcher,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  Icon(Icons.folder_special_outlined, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noWorkspaceHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newWorkspace),
                    onPressed: () => newWorkspace(context, ref),
                  ),
                ],
              ),
            ),
          for (final w in all)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                color: w.id == switcher.currentId ? scheme.secondaryContainer : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Builder(
                  builder: (tileContext) => InkWell(
                    onTap: () => showNuxMenu(
                      tileContext,
                      beside: true,
                      (_) => [
                        NuxMenuAction(
                          icon: Icons.open_in_new,
                          label: l10n.openWorkspace,
                          enabled: w.id != switcher.currentId,
                          onSelected: () => switcher.switchTo(w.id),
                        ),
                        NuxMenuAction(
                          icon: Icons.edit_outlined,
                          label: l10n.rename,
                          onSelected: () => renameWorkspace(context, ref, w),
                        ),
                        const NuxMenuDivider(),
                        NuxMenuAction(
                          icon: Icons.delete_outline,
                          label: l10n.deleteWorkspace,
                          onSelected: () => deleteWorkspace(context, ref, w),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Icon(Icons.folder_special_outlined, color: scheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                                StartEllipsisText(
                                  '${hosts[w.connectionId] ?? ''} · ${w.rootPath}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          if (w.id == switcher.currentId)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                l10n.currentWorkspace,
                                style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                              ),
                            ),
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

class _HostsView extends ConsumerStatefulWidget {
  const _HostsView({required this.tab});

  final HostsTab tab;

  @override
  ConsumerState<_HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends ConsumerState<_HostsView> {
  late final Timer _ping;

  @override
  void initState() {
    super.initState();
    // Pings refresh while the list is shown (the tab is unmounted when parked).
    _ping = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidate(hostPingProvider));
  }

  @override
  void dispose() {
    _ping.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final pool = ref.watch(sshPoolProvider);
    final rules = <String, List<ForwardRule>>{};
    for (final r in ref.watch(forwardRulesProvider).value ?? const <ForwardRule>[]) {
      if (r.connectionId case final id?) rules.putIfAbsent(id, () => []).add(r);
    }

    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([pool, widget.tab.openForwardings]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          children: [
            if (all.isEmpty) const _Empty(),
            for (final (i, c) in all.indexed) ...[
              if (c.groupName != null && (i == 0 || all[i - 1].groupName != c.groupName))
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
                  child: Text(
                    c.groupName!,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              _HostTile(
                connection: c,
                state: pool.state(c.id),
                rules: rules[c.id] ?? const [],
                open: widget.tab.openForwardings.value.contains(c.id),
                onToggle: () => widget.tab.toggleForwardings(c.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A host as a small tile: reachability (TCP ping to the SSH port), name, address. Tapping opens its menu;
/// the button at the end slides its forwardings out below it. While they are hidden and some run, a strip
/// under the tile says how many and how much traffic.
class _HostTile extends ConsumerWidget {
  const _HostTile({
    required this.connection,
    required this.state,
    required this.rules,
    required this.open,
    required this.onToggle,
  });

  final Connection connection;
  final SshState state;
  final List<ForwardRule> rules;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = connection;
    final manager = ref.watch(forwardingManagerProvider);
    final tile = Padding(
      padding: EdgeInsets.fromLTRB(12, 3, 12, open ? 0 : 3),
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: open ? const BorderRadius.vertical(top: Radius.circular(14)) : BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Builder(
              builder: (tileContext) => InkWell(
                onTap: () => showNuxMenu(tileContext, (_) => _menu(context, ref), beside: true),
                child: Container(
                  decoration: c.color == null
                      ? null
                      : BoxDecoration(
                          border: Border(left: BorderSide(color: Color(c.color!), width: 4)),
                        ),
                  padding: EdgeInsets.fromLTRB(c.color == null ? 12 : 8, 10, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(width: 52, child: _Ping(connection: c)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              c.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (state == SshState.connecting)
                        const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (state == SshState.connected)
                        Icon(Icons.link, size: 18, color: scheme.primary, semanticLabel: context.l10n.connected),
                      const SizedBox(width: 4),
                      _ForwardingsButton(open: open, onPressed: onToggle),
                    ],
                  ),
                ),
              ),
            ),
            if (!open)
              ListenableBuilder(
                listenable: manager,
                builder: (context, _) =>
                    forwardingsPeek(context, manager, rules, onToggle) ?? const SizedBox(width: double.infinity),
              ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        tile,
        // Slides out from under the tile.
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open ? HostForwardings(host: c, rules: rules) : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  List<NuxMenuItem> _menu(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = connection;
    return [
      NuxMenuCustom(
        (menuContext) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.terminal, size: 18),
                  label: const Text('SSH'),
                  onPressed: () => Navigator.of(menuContext).pop<VoidCallback>(() => openTerminal(ref, c.id)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.folder_outlined, size: 18),
                  label: const Text('SFTP'),
                  onPressed: () => Navigator.of(menuContext).pop<VoidCallback>(() => openFiles(ref, c.id)),
                ),
              ),
            ],
          ),
        ),
      ),
      NuxMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.edit,
        onSelected: () => context.push(Routes.connection(c.id)),
      ),
      NuxMenuAction(
        icon: Icons.copy_all,
        label: l10n.duplicate,
        onSelected: () => duplicateConnection(context, ref, c),
      ),
      if (state != SshState.disconnected)
        NuxMenuAction(
          icon: Icons.link_off,
          label: l10n.disconnect,
          onSelected: () => ref.read(sshPoolProvider).disconnect(c.id),
        ),
      const NuxMenuDivider(),
      NuxMenuAction(
        icon: Icons.delete_outline,
        label: l10n.delete,
        onSelected: () => deleteConnection(context, ref, c),
      ),
    ];
  }
}

/// A coloured dot and the round-trip time; grey when it cannot be measured (behind a jump host and not
/// connected, or its ZeroTier network is not up) or while measuring, red when there is no answer.
class _Ping extends ConsumerWidget {
  const _Ping({required this.connection});

  final Connection connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = connection;
    final ping = ref.watch(
      hostPingProvider((
        id: c.id,
        host: c.host,
        port: c.port,
        network: c.zerotierNetwork,
        viaJump: c.jumpHostId != null,
      )),
    );
    // While a refresh runs the previous result stays shown.
    final waiting = theme.colorScheme.outlineVariant;
    final (Color color, String label, bool hollow) = switch (ping.value) {
      null => (waiting, '…', false),
      Ping(measured: false) => (theme.colorScheme.outline, '', false),
      // No reply: just an outline in the "waiting" colour, no text (the reason is in the tooltip).
      Ping(rtt: null) => (waiting, '', true),
      Ping(:final rtt?) => (pingColor(rtt.inMilliseconds), context.l10n.pingMs(rtt.inMilliseconds), false),
    };
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: hollow ? null : color,
        border: hollow ? Border.all(color: color, width: 1.5) : null,
        shape: BoxShape.circle,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hollow) Tooltip(message: context.l10n.pingFailed, child: dot) else dot,
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Green when snappy, amber when noticeable, red-orange when slow.
Color pingColor(int ms) => ms < 80
    ? const Color(0xFF43A047)
    : ms < 250
    ? const Color(0xFFF9A825)
    : const Color(0xFFEF6C00);

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(Icons.dns_outlined, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.noHosts, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.noHostsHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addHost),
                onPressed: () => context.push(Routes.newConnection),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.key),
                label: Text(l10n.keys),
                onPressed: () => context.push(Routes.keys),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A chevron that slides the host's port forwardings out (turned up while they are shown).
class _ForwardingsButton extends StatelessWidget {
  const _ForwardingsButton({required this.open, required this.onPressed});

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.forwardings,
      onPressed: onPressed,
      icon: AnimatedRotation(
        turns: open ? .5 : 0,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.expand_more, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
