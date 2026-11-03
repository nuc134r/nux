import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_providers.dart';
import '../../../core/background/keep_alive.dart';
import '../../../core/log/log.dart';
import '../../../l10n/l10n.dart';
import '../../files/domain/file_listing.dart';
import '../../ssh/data/ssh_providers.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../zerotier/domain/zt_forward.dart';
import '../domain/forward_rule.dart';
import '../domain/forwarder.dart';
import '../domain/forwarding_manager.dart';
import 'forward_rule_repository.dart';

/// Forwarding's share of the background service (after the SSH sessions in the notification).
final keepAliveProvider = Provider<KeepAlive>((ref) => ref.watch(keepAliveHubProvider).slot('forwarding', order: 1));

final forwardingManagerProvider = Provider((ref) {
  final pool = ref.read(sshPoolProvider);
  final manager = ForwardingManager(
    connect: (rule) async {
      final network = rule.zerotierNetwork;
      if (rule.forwardKind.overZeroTier && network != null) {
        final zerotier = ref.read(zeroTierServiceProvider);
        await zerotier.ensureNetwork(network);
        return ForwardLease(client: network, done: zerotier.stopped, release: () {});
      }
      final lease = await pool.acquire(rule.connectionId!, ref.read(sshPrompterProvider));
      return ForwardLease(client: lease.client, done: lease.done, release: lease.release);
    },
    startForward: (lease, rule, onChange) => switch (rule.forwardKind) {
      ForwardKind.zerotierTcp => startZeroTierTcpForward(
          bindHost: rule.bindHost,
          bindPort: rule.bindPort,
          targetHost: rule.targetHost,
          targetPort: rule.targetPort,
          onChange: onChange,
        ),
      ForwardKind.zerotierUdp => startZeroTierUdpForward(
          bindHost: rule.bindHost,
          bindPort: rule.bindPort,
          targetHost: rule.targetHost,
          targetPort: rule.targetPort,
          onChange: onChange,
        ),
      _ => startForward(
          lease.client as SSHClient,
          kind: rule.forwardKind,
          bindHost: rule.bindHost,
          bindPort: rule.bindPort,
          targetHost: rule.targetHost,
          targetPort: rule.targetPort,
          onChange: onChange,
        ),
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
  return manager;
});

/// Starts the "start with nux" rules once, after launch.
final forwardingAutoStartProvider = FutureProvider<void>((ref) async {
  final rules = await ref.read(forwardRuleRepositoryProvider).all();
  await ref.read(forwardingManagerProvider).startAuto(rules);
});
