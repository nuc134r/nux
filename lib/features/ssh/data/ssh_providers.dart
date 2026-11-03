import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../../../core/log/log.dart';
import '../../zerotier/data/zerotier_service.dart';
import '../../connections/data/connection_repository.dart';
import '../../connections/data/known_hosts_repository.dart';
import '../../identities/data/identity_repository.dart';
import '../domain/ssh_prompter.dart';
import '../presentation/prompter_provider.dart';
import 'ssh_connector.dart';
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
