import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_center.dart';
import '../presentation/forwarding_widgets.dart' show forwardErrorText;

import '../../../core/background/background_providers.dart';
import '../../../core/background/keep_alive.dart';
import '../../../core/log/log.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart';
import '../../connections/data/connection_repository.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../zerotier/domain/zt_forward.dart';
import '../domain/forward_rule.dart';
import '../domain/forwarder.dart';
import '../domain/forwarding_manager.dart';
import 'forward_rule_repository.dart';

/// Forwarding's share of the background service (after the SSH sessions in the notification).
final keepAliveProvider = Provider<KeepAlive>((ref) => ref.watch(keepAliveHubProvider).slot('forwarding', order: 1));

/// What a direct ZeroTier rule's lease carries: where in the network to go.
class _ZeroTierTarget {
  const _ZeroTierTarget(this.address);

  final String address;
}

final forwardingManagerProvider = Provider((ref) {
  final pool = ref.read(sshPoolProvider);
  final manager = ForwardingManager(
    connect: (rule) async {
      final id = rule.connectionId;
      final host = id == null ? null : await ref.read(connectionRepositoryProvider).get(id);
      if (host == null) throw const ForwardException(ForwardError.other, 'The host of this forwarding is gone');
      if (rule.routeVia(host) == ForwardRoute.zeroTier) {
        final zerotier = ref.read(zeroTierServiceProvider);
        await zerotier.ensureNetwork(host.zerotierNetwork!);
        return ForwardLease(client: _ZeroTierTarget(host.host), done: zerotier.stopped, release: () {});
      }
      final lease = await pool.acquire(host.id, ref.read(sshPrompterProvider));
      return ForwardLease(client: lease.client, done: lease.done, release: lease.release);
    },
    startForward: (lease, rule, onChange) async {
      if (lease.client case _ZeroTierTarget(:final address)) {
        final parts = <RunningForward>[];
        try {
          if (rule.tcp) {
            parts.add(
              await startZeroTierTcpForward(
                bindHost: rule.bindHost,
                bindPort: rule.bindPort,
                targetHost: address,
                targetPort: rule.targetPort,
                onChange: onChange,
              ),
            );
          }
          if (rule.udp) {
            parts.add(
              await startZeroTierUdpForward(
                bindHost: rule.bindHost,
                bindPort: rule.bindPort,
                targetHost: address,
                targetPort: rule.targetPort,
                onChange: onChange,
              ),
            );
          }
        } catch (_) {
          for (final p in parts) {
            await p.close();
          }
          rethrow;
        }
        return parts.length == 1 ? parts.single : CombinedForward(parts);
      }
      return startForward(
        lease.client as SSHClient,
        kind: rule.forwardKind,
        bindHost: rule.bindHost,
        bindPort: rule.bindPort,
        targetHost: rule.targetHost,
        targetPort: rule.targetPort,
        onChange: onChange,
      );
    },
    keepAlive: ref.read(keepAliveProvider),
    log: ref.read(logProvider),
    texts: () {
      final l10n = currentL10n.value;
      return ForwardingTexts(
        title: l10n.forwardingActive,
        text: (bytesIn, bytesOut) => l10n.forwardingTraffic(formatSize(bytesIn), formatSize(bytesOut)),
        stop: l10n.stopAll,
      );
    },
  );
  ref.onDispose(manager.dispose);
  _reportForwardings(manager, ref.read(activityCenterProvider));
  return manager;
});

/// A forwarding that stops on an error, or works again after one, is an Activity event (with Try again).
void _reportForwardings(ForwardingManager manager, ActivityCenter center) {
  final last = <String, ForwardState>{};
  manager.addListener(() {
    for (final rule in manager.rules.values) {
      final s = manager.status(rule.id);
      final before = last[rule.id];
      last[rule.id] = s.state;
      if (before == s.state) continue;
      final l10n = currentL10n.value;
      final name = rule.label.isNotEmpty ? rule.label : rule.describe();
      if (s.state == ForwardState.failed) {
        center.event(
          ActivitySource.forwarding,
          l10n.activityForwardFailed(name),
          subtitle: s.error == null ? null : forwardErrorText(l10n, s.error!, rule),
          state: ActivityState.failed,
          retry: () => manager.start(rule),
        );
      } else if (s.state == ForwardState.active && before == ForwardState.reconnecting) {
        center.event(ActivitySource.forwarding, l10n.activityForwardBack(name), state: ActivityState.done, unread: false);
      }
    }
  });
}

/// Starts the "start with nux" rules once, after launch.
final forwardingAutoStartProvider = FutureProvider<void>((ref) async {
  final rules = await ref.read(forwardRuleRepositoryProvider).all();
  await ref.read(forwardingManagerProvider).startAuto(rules);
});
