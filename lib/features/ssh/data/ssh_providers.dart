import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/log/log.dart';
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
    ));

final sshPoolProvider = Provider((ref) {
  final pool = SshPool(ref.watch(sshConnectorProvider), ref.watch(logProvider));
  ref.onDispose(pool.dispose);
  return pool;
});

/// Answers the SSH layer's questions with dialogs; tests override it with a fake.
final sshPrompterProvider = Provider<SshPrompter>((ref) => ref.watch(dialogSshPrompterProvider));
