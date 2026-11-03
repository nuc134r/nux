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

IconData forwardIcon(ForwardKind kind) => switch (kind) {
      ForwardKind.local => Icons.call_made,
      ForwardKind.remote => Icons.call_received,
      ForwardKind.dynamic => Icons.hub_outlined,
    };

String forwardKindLabel(AppLocalizations l10n, ForwardKind kind) => switch (kind) {
      ForwardKind.local => l10n.forwardLocal,
      ForwardKind.remote => l10n.forwardRemote,
      ForwardKind.dynamic => l10n.forwardDynamic,
    };

String forwardErrorText(AppLocalizations l10n, Object error, ForwardRule rule) => switch (error) {
      ForwardException(error: ForwardError.portInUse) => l10n.forwardPortInUse(rule.bindPort),
      ForwardException(error: ForwardError.bindDenied) => l10n.forwardBindDenied(rule.bindPort),
      ForwardException(error: ForwardError.remoteRefused) => l10n.forwardRemoteRefused,
      ForwardException(:final message) => l10n.errorGeneric(message),
      SshConnectException() => sshErrorText(l10n, error),
      _ => l10n.errorGeneric('$error'),
    };

/// One line about what a rule is doing right now.
String forwardStatusText(AppLocalizations l10n, ForwardStatus s, ForwardRule rule) {
  final stats = s.stats;
  return switch (s.state) {
    ForwardState.stopped => l10n.forwardOff,
    ForwardState.starting => l10n.forwardStarting,
    ForwardState.active when stats != null && rule.forwardKind == ForwardKind.dynamic =>
      l10n.forwardActiveConnections(stats.connections),
    ForwardState.active when stats != null =>
      l10n.forwardActiveTraffic(stats.open, formatSize(stats.bytesIn), formatSize(stats.bytesOut)),
    ForwardState.active => l10n.forwardActive,
    ForwardState.reconnecting => l10n.forwardReconnecting(s.attempt),
    ForwardState.failed => s.error == null ? l10n.forwardFailed : forwardErrorText(l10n, s.error!, rule),
  };
}

/// A rule with an on/off switch; tap to edit.
class ForwardRuleTile extends ConsumerWidget {
  const ForwardRuleTile({super.key, required this.rule, this.connectionName, this.dense = false});

  final ForwardRule rule;
  final String? connectionName;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final manager = ref.watch(forwardingManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final s = manager.status(rule.id);
        final title = rule.label.isNotEmpty ? rule.label : rule.describe();
        final service = wellKnownPorts[rule.forwardKind == ForwardKind.remote ? rule.bindPort : rule.targetPort];
        final details = [
          if (rule.label.isNotEmpty) rule.describe(),
          ?connectionName,
          if (rule.label.isEmpty && service != null && rule.forwardKind != ForwardKind.dynamic) service,
        ].join(' · ');
        return ListTile(
          dense: dense,
          leading: Icon(
            forwardIcon(rule.forwardKind),
            color: switch (s.state) {
              ForwardState.active => Colors.green,
              ForwardState.failed => scheme.error,
              ForwardState.starting || ForwardState.reconnecting => Colors.amber,
              _ => null,
            },
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [if (details.isNotEmpty) details, forwardStatusText(l10n, s, rule)].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: s.state == ForwardState.failed ? TextStyle(color: scheme.error) : null,
          ),
          isThreeLine: details.isNotEmpty,
          trailing: Switch(
            value: s.on,
            onChanged: (v) => v ? manager.start(rule) : manager.stop(rule.id),
          ),
          onTap: () => context.push(Routes.forward(rule.id)),
        );
      },
    );
  }
}
