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
  reportForwardings(manager, ref.read(activityCenterProvider));
  return manager;
});

/// Forwardings in Activity: starting and reconnecting are operations (Cancel stops the forwarding), a
/// forwarding that gives up is a failure (with Try again), and turning one off is noted.
void reportForwardings(ForwardingManager manager, ActivityCenter center) {
  final last = <String, ForwardState>{};
  final entries = <String, ActivityEntry>{};
  manager.addListener(() {
    for (final rule in manager.rules.values) {
      final s = manager.status(rule.id);
      final before = last[rule.id] ?? ForwardState.stopped;
      final attempt = s.attempt;
      last[rule.id] = s.state;
      final l10n = currentL10n.value;
      final name = rule.label.isNotEmpty ? rule.label : rule.describe();
      final error = s.error == null ? null : forwardErrorText(l10n, s.error!, rule);
      final entry = entries[rule.id];
      void begin(String subtitle) => entries[rule.id] = center.start(
        ActivitySource.forwarding,
        l10n.activityForwarding(name),
        subtitle: subtitle,
        cancel: () => manager.stop(rule.id),
      );
      if (before == s.state) {
        // Another attempt while reconnecting.
        if (s.state == ForwardState.reconnecting && entry != null) {
          center.update(entry, subtitle: l10n.forwardReconnecting(attempt));
        }
        continue;
      }
      switch (s.state) {
        case ForwardState.starting:
          begin(l10n.forwardStarting);
        case ForwardState.reconnecting:
          if (entry == null || !entry.running) {
            begin(l10n.forwardReconnecting(attempt));
          } else {
            center.update(entry, subtitle: l10n.forwardReconnecting(attempt));
          }
        case ForwardState.active:
          if (entry != null && entry.running) {
            center.finish(
              entry,
              ActivityState.done,
              subtitle: before == ForwardState.reconnecting ? l10n.activityForwardBackShort : rule.describe(),
              unread: false,
            );
          }
        case ForwardState.failed:
          if (entry != null && entry.running) {
            entry.retry = () => manager.start(rule);
            center.finish(entry, ActivityState.failed, subtitle: error);
          } else {
            center.event(
              ActivitySource.forwarding,
              l10n.activityForwardFailed(name),
              subtitle: error,
              state: ActivityState.failed,
              retry: () => manager.start(rule),
            );
          }
        case ForwardState.stopped:
          if (entry != null && entry.running) center.finish(entry, ActivityState.cancelled, unread: false);
          if (before != ForwardState.failed) {
            center.event(ActivitySource.forwarding, l10n.activityForwardStopped(name), unread: false);
          }
      }
    }
  });
}

/// Starts the "start with nux" rules once, after launch.
final forwardingAutoStartProvider = FutureProvider<void>((ref) async {
  final rules = await ref.read(forwardRuleRepositoryProvider).all();
  await ref.read(forwardingManagerProvider).startAuto(rules);
});
