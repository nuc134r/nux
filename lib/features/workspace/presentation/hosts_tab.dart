import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/host_ping.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../ssh/data/ssh_pool.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../forwarding/data/forward_rule_repository.dart';
import '../../forwarding/data/forwarding_providers.dart';
import '../../forwarding/presentation/forwarding_widgets.dart';
import '../../updates/presentation/update_ui.dart';
import '../domain/nux_tab.dart';

/// The saved hosts. There is one at most (opening it again selects it).
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
  String get title => currentL10n.value.hosts;

  @override
  IconData get icon => Icons.dns_outlined;

  /// Hosts whose forwardings are shown.
  final openForwardings = ValueNotifier<Set<String>>(const {});

  void toggleForwardings(String hostId) {
    final open = {...openForwardings.value};
    if (!open.remove(hostId)) open.add(hostId);
    openForwardings.value = open;
  }

  @override
  Widget buildContent(BuildContext context) => _HostsView(tab: this);

  @override
  List<NuxMenuItem> menuEntries(BuildContext context) => [
    NuxMenuAction(icon: Icons.add, label: context.l10n.addHost, onSelected: () => context.push(Routes.newConnection)),
  ];

  @override
  void dispose() {
    currentL10n.removeListener(notifyListeners);
    openForwardings.dispose();
    super.dispose();
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
            const UpdateBanner(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      _ForwardingsButton(count: rules.length, open: open, onPressed: onToggle),
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
                icon: const Icon(Icons.bolt),
                label: Text(l10n.quickConnect),
                onPressed: () => quickConnect(context, ref),
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

/// ⇄ with the number of forwardings and a chevron; filled while they are shown.
class _ForwardingsButton extends StatelessWidget {
  const _ForwardingsButton({required this.count, required this.open, required this.onPressed});

  final int count;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = open ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Tooltip(
      message: context.l10n.forwardings,
      child: Material(
        color: open ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: count == 0 ? 8 : 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz, size: 20, color: color),
                  if (count > 0) ...[
                    const SizedBox(width: 2),
                    Text('$count', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
                    AnimatedRotation(
                      turns: open ? .5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, size: 18, color: color),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
