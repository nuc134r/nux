import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../core/widgets/nux_menu.dart';
import '../../../core/widgets/widgets.dart' show showSnack;
import '../../../l10n/l10n.dart';
import '../../browser/domain/address.dart';
import '../../browser/presentation/browser_tab.dart';
import '../../workspace/data/workspace.dart';
import '../../files/domain/file_listing.dart';
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/presentation/ssh_errors.dart';
import '../data/forward_rule_repository.dart';
import '../data/forwarding_providers.dart';
import '../domain/forward_rule.dart';
import '../domain/forwarder.dart';
import '../domain/forwarding_manager.dart';

String forwardErrorText(AppLocalizations l10n, Object error, ForwardRule rule) => switch (error) {
  ForwardException(error: ForwardError.portInUse) => l10n.forwardPortInUse(rule.bindPort),
  ForwardException(error: ForwardError.bindDenied) => l10n.forwardBindDenied(rule.bindPort),
  ForwardException(error: ForwardError.remoteRefused) => l10n.forwardRemoteRefused,
  ForwardException(:final message) => l10n.errorGeneric(message),
  SshConnectException() => sshErrorText(l10n, error),
  _ => l10n.errorGeneric('$error'),
};

/// A host's forwardings, shown under its tile: no background, one row each, then "Add forwarding".
class HostForwardings extends StatelessWidget {
  const HostForwardings({super.key, required this.host, required this.rules});

  final Connection host;
  final List<ForwardRule> rules;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A subtle panel hanging from the host tile: square on top, rounded at the bottom.
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rules) ...[
            ForwardingRow(rule: r),
            Divider(height: 1, indent: 12, endIndent: 12, color: scheme.outlineVariant.withValues(alpha: .5)),
          ],
          // The whole row is the button, no outline.
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            onTap: () => context.push(Routes.newForward(host.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Icon(Icons.add, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.addPortForwarding,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks, stops the forward if it runs, deletes it and says so.
Future<void> deleteForwarding(BuildContext context, WidgetRef ref, ForwardRule rule) async {
  final l10n = context.l10n;
  final name = rule.label.isNotEmpty ? rule.label : rule.describe();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deleteForwardTitle(name)),
      content: Text(l10n.deleteForwardBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(forwardingManagerProvider).stop(rule.id);
  await ref.read(forwardRuleRepositoryProvider).delete(rule.id);
  if (context.mounted) showSnack(context, l10n.deleted(name));
}

/// `Database` / `8080 → 8020 [TCP] [UDP]` with a switch, and traffic chips while it runs. Tap for its menu.
class ForwardingRow extends ConsumerWidget {
  const ForwardingRow({super.key, required this.rule});

  final ForwardRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.watch(forwardingManagerProvider);
    final name = rule.label.isNotEmpty
        ? rule.label
        : rule.forwardKind == ForwardKind.dynamic
        ? null
        : wellKnownPorts[rule.targetPort];
    final ports = theme.textTheme.bodyMedium?.copyWith(
      color: name == null ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final s = manager.status(rule.id);
        final stats = s.stats;
        final note = switch (s.state) {
          ForwardState.starting => l10n.forwardStarting,
          ForwardState.reconnecting => l10n.forwardReconnecting(s.attempt),
          ForwardState.failed => s.error == null ? l10n.forwardFailed : forwardErrorText(l10n, s.error!, rule),
          _ => null,
        };
        void menu() => showNuxMenu(
          context,
          beside: true,
          (_) => [
            // A forward that listens here can be opened as a web page (http://localhost:port).
            if (rule.forwardKind != ForwardKind.remote)
              NuxMenuAction(
                icon: Icons.public,
                label: l10n.openInBrowserTab,
                onSelected: () {
                  if (!s.on) manager.start(rule);
                  openBrowserTab(ref.read(workspaceProvider), '${forwardedPortUri(rule.bindPort)}');
                },
              ),
            NuxMenuAction(
              icon: Icons.edit_outlined,
              label: l10n.edit,
              onSelected: () => context.push(Routes.forward(rule.id)),
            ),
            const NuxMenuDivider(),
            NuxMenuAction(
              icon: Icons.delete_outline,
              label: l10n.delete,
              onSelected: () => deleteForwarding(context, ref, rule),
            ),
          ],
        );
        return InkWell(
          // Tap and long press both open the menu (the switch turns it on and off).
          onTap: menu,
          onLongPress: menu,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (name != null)
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(rule.describe(), style: ports),
                              if (rule.forwardKind != ForwardKind.dynamic) ...[
                                if (rule.tcp) const _Badge('TCP'),
                                if (rule.udp) const _Badge('UDP'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(value: s.on, onChanged: (v) => v ? manager.start(rule) : manager.stop(rule.id)),
                  ],
                ),
                if (note != null)
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: s.state == ForwardState.failed ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  )
                else if (s.state == ForwardState.active && stats != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          l10n.forwardConnections(
                            rule.forwardKind == ForwardKind.dynamic ? stats.connections : stats.open,
                          ),
                        ),
                        _Chip('↓ ${formatSize(stats.bytesIn)}'),
                        _Chip('↑ ${formatSize(stats.bytesOut)}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Under a closed host whose forwardings run: how many and the traffic. Null when none runs.
Widget? forwardingsPeek(BuildContext context, ForwardingManager manager, List<ForwardRule> rules, VoidCallback onTap) {
  final on = rules.where((r) => manager.status(r.id).on).toList();
  if (on.isEmpty) return null;
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  var bytesIn = 0, bytesOut = 0, connections = 0;
  for (final r in on) {
    connections += manager.status(r.id).stats?.open ?? 0;
    bytesIn += manager.status(r.id).stats?.bytesIn ?? 0;
    bytesOut += manager.status(r.id).stats?.bytesOut ?? 0;
  }
  final failed = on.any((r) => manager.status(r.id).state != ForwardState.active);
  final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
  return Material(
    color: scheme.surfaceContainerHigh,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: failed ? Colors.amber : Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '${context.l10n.portsCount(on.length)}, ${context.l10n.forwardConnections(connections)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 12),
            Text('↓ ${formatSize(bytesIn)}', style: muted),
            const SizedBox(width: 10),
            Text('↑ ${formatSize(bytesOut)}', style: muted),
          ],
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: .4,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
