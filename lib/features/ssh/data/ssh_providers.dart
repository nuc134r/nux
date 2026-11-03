import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../core/background/background_providers.dart';
import '../../../core/log/log.dart';
import '../../../l10n/l10n.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/known_hosts_repository.dart';
import '../../identities/data/identity_repository.dart';
import '../domain/ssh_prompter.dart';
import '../presentation/prompter_provider.dart';
import 'ssh_connector.dart';
import 'ssh_keep_alive.dart';
import 'ssh_pool.dart';

final sshConnectorProvider = Provider((ref) => SshConnector(
      connections: ref.watch(connectionRepositoryProvider),
      identities: ref.watch(identityRepositoryProvider),
      knownHosts: ref.watch(knownHostsRepositoryProvider),
      log: ref.watch(logProvider),
      zerotierSocket: (network, host, port, timeout) async {
        await ref.read(zeroTierServiceProvider).ensureNetwork(network);
        return ZeroTierSshSocket(await ZeroTierSocket.connect(host, port, timeout: timeout));
      },
    ));

final sshPoolProvider = Provider((ref) {
  final pool = SshPool(ref.watch(sshConnectorProvider), ref.watch(logProvider));
  ref.onDispose(pool.dispose);
  return pool;
});

/// Answers the SSH layer's questions with dialogs; tests override it with a fake.
final sshPrompterProvider = Provider<SshPrompter>((ref) => ref.watch(dialogSshPrompterProvider));

/// Keeps the app alive in the background while SSH connections are in use; watched by the workspace.
final sshKeepAliveProvider = Provider((ref) {
  final keepAlive = SshKeepAlive(
    ref.watch(sshPoolProvider),
    ref.watch(keepAliveHubProvider).slot('ssh'),
    title: (n) => currentL10n.value.sshConnectionsOpen(n),
    stopLabel: () => currentL10n.value.disconnectAll,
  );
  ref.onDispose(keepAlive.dispose);
  return keepAlive;
});
