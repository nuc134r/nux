import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/db/database.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart';
import '../../ssh/data/ssh_connector.dart';
import '../../ssh/presentation/ssh_errors.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.addPortForwarding),
              onPressed: () => context.push(Routes.newForward(host.id)),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Database` / `8080 → 8020 [TCP] [UDP]` with a switch, and traffic chips while it runs. Tap to edit.
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
        return InkWell(
          onTap: () => context.push(Routes.forward(rule.id)),
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
