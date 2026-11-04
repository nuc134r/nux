import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../ssh/data/sftp_file_system.dart';
import '../../ssh/data/ssh_backend.dart';
import '../../ssh/data/ssh_providers.dart';

/// Files and commands on a workspace's host, held until [release].
class WorkspaceAccess {
  WorkspaceAccess({required this.fs, required this.runner, required this.release});

  final FileSystem fs;
  final ProcessRunner runner;
  final void Function() release;
}

typedef WorkspaceOpener = Future<WorkspaceAccess> Function(String connectionId);

/// Over the shared SSH connection of the host (tests override it with local files and commands).
final workspaceOpenerProvider = Provider<WorkspaceOpener>((ref) {
  final pool = ref.watch(sshPoolProvider);
  return (connectionId) async {
    final lease = await pool.acquire(connectionId, ref.read(sshPrompterProvider));
    final fs = SftpFileSystem(lease.client);
    return WorkspaceAccess(
      fs: fs,
      runner: SshProcessRunner(lease.client),
      release: () {
        fs.close();
        lease.release();
      },
    );
  };
});
