import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../connections/data/connection_repository.dart';
import '../data/forward_rule_repository.dart';
import '../data/forwarding_providers.dart';
import 'forwarding_widgets.dart';

/// All forwarding rules, grouped by host (or one host's, with [connectionId]).
class ForwardingScreen extends ConsumerWidget {
  const ForwardingScreen({super.key, this.connectionId});

  final String? connectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rules = (ref.watch(forwardRulesProvider).value ?? const <ForwardRule>[])
        .where((r) => connectionId == null || r.connectionId == connectionId)
        .toList();
    final connections = {for (final c in ref.watch(connectionsProvider).value ?? const <Connection>[]) c.id: c};
    final manager = ref.watch(forwardingManagerProvider);
    final names = {for (final MapEntry(:key, :value) in connections.entries) key: value.name};
    final byHost = <String, List<ForwardRule>>{};
    for (final r in rules) {
      byHost.putIfAbsent(forwardVia(l10n, r, names), () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(connectionId == null ? l10n.portForwarding : l10n.portForwardingOn(connections[connectionId]?.name ?? '')),
        actions: [
          ListenableBuilder(
            listenable: manager,
            builder: (context, _) => manager.activeCount == 0
                ? const SizedBox.shrink()
                : TextButton(onPressed: manager.stopAll, child: Text(l10n.stopAll)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addForward),
        onPressed: () => context.push(Routes.newForward(connectionId: connectionId)),
      ),
      body: rules.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.swap_horiz, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.noForwards, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                for (final (icon, title, text) in [
                  (Icons.call_made, l10n.forwardLocal, l10n.forwardLocalHint),
                  (Icons.call_received, l10n.forwardRemote, l10n.forwardRemoteHint),
                  (Icons.hub_outlined, l10n.forwardDynamic, l10n.forwardDynamicHint),
                ])
                  ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(text)),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l10n.forwardingBackgroundHint, style: theme.textTheme.bodySmall),
                ),
                for (final MapEntry(key: via, value: list) in byHost.entries)
                  Island(
                    title: connectionId == null ? via : null,
                    children: [for (final r in list) ForwardRuleTile(rule: r)],
                  ),
              ],
            ),
    );
  }
}
