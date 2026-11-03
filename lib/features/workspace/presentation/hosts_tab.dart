import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/presentation/connection_actions.dart';
import '../../ssh/data/ssh_pool.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../forwarding/data/forward_rule_repository.dart';
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

  @override
  Widget buildContent(BuildContext context) => const _HostsView();

  @override
  void dispose() {
    currentL10n.removeListener(notifyListeners);
    super.dispose();
  }
}

class _HostsView extends ConsumerStatefulWidget {
  const _HostsView();

  @override
  ConsumerState<_HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends ConsumerState<_HostsView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(connectionsProvider).value ?? const <Connection>[];
    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? all
        : all
            .where((c) => [c.name, c.host, c.username, c.groupName ?? ''].any((f) => f.toLowerCase().contains(query)))
            .toList();
    final pool = ref.watch(sshPoolProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.add),
        label: Text(l10n.addHost),
        onPressed: () => context.push(Routes.newConnection),
      ),
      body: ListenableBuilder(
        listenable: pool,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const UpdateBanner(),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SearchBar(
                  controller: _search,
                  hintText: l10n.searchHosts,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            if (all.isEmpty) const _Empty() else const _ForwardingToggles(),
            for (final (i, c) in shown.indexed) ...[
              if (c.groupName != null && (i == 0 || shown[i - 1].groupName != c.groupName))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    c.groupName!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              _HostTile(connection: c, state: pool.state(c.id), jumpName: _jumpName(all, c)),
            ],
          ],
        ),
      ),
    );
  }

  String? _jumpName(List<Connection> all, Connection c) {
    if (c.jumpHostId == null) return null;
    for (final j in all) {
      if (j.id == c.jumpHostId) return j.name;
    }
    return null;
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile({required this.connection, required this.state, required this.jumpName});

  final Connection connection;
  final SshState state;
  final String? jumpName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final c = connection;
    final color = c.color == null ? scheme.secondaryContainer : Color(c.color!);
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    return ListTile(
      leading: Badge(
        isLabelVisible: state != SshState.disconnected,
        backgroundColor: state == SshState.connected ? Colors.green : Colors.amber,
        smallSize: 10,
        child: CircleAvatar(
          backgroundColor: color,
          foregroundColor: onColor,
          child: Text(c.name.isEmpty ? '?' : c.name.characters.first.toUpperCase()),
        ),
      ),
      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        jumpName == null ? c.address : l10n.addressVia(c.address, jumpName!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => openTerminal(ref, c.id),
      trailing: PopupMenuButton<VoidCallback>(
        tooltip: l10n.more,
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: () => openTerminal(ref, c.id),
            child: ListTile(leading: const Icon(Icons.terminal), title: Text(l10n.openTerminal)),
          ),
          PopupMenuItem(
            value: () => openFiles(ref, c.id),
            child: ListTile(leading: const Icon(Icons.folder_outlined), title: Text(l10n.browseFiles)),
          ),
          PopupMenuItem(
            value: () => context.push(Routes.forwardingFor(c.id)),
            child: ListTile(leading: const Icon(Icons.swap_horiz), title: Text(l10n.portForwarding)),
          ),
          PopupMenuItem(
            value: () => context.push(Routes.connection(c.id)),
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.edit)),
          ),
          PopupMenuItem(
            value: () => duplicateConnection(context, ref, c),
            child: ListTile(leading: const Icon(Icons.copy_all), title: Text(l10n.duplicate)),
          ),
          if (state != SshState.disconnected)
            PopupMenuItem(
              value: () => ref.read(sshPoolProvider).disconnect(c.id),
              child: ListTile(leading: const Icon(Icons.link_off), title: Text(l10n.disconnect)),
            ),
          PopupMenuItem(
            value: () => deleteConnection(context, ref, c),
            child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.delete)),
          ),
        ],
      ),
    );
  }
}

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

/// Quick on/off switches for forwarding rules at the top of the hosts list.
class _ForwardingToggles extends ConsumerWidget {
  const _ForwardingToggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rules = ref.watch(forwardRulesProvider).value ?? const <ForwardRule>[];
    if (rules.isEmpty) return const SizedBox.shrink();
    final names = {for (final c in ref.watch(connectionsProvider).value ?? const <Connection>[]) c.id: c.name};
    const shown = 4;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(l10n.portForwarding, style: Theme.of(context).textTheme.titleSmall),
            trailing: TextButton(onPressed: () => context.push(Routes.forwarding), child: Text(l10n.allRules(rules.length))),
          ),
          for (final r in rules.take(shown)) ForwardRuleTile(rule: r, connectionName: names[r.connectionId], dense: true),
        ],
      ),
    );
  }
}
