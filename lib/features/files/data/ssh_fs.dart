import '../../ssh/data/sftp_file_system.dart';
import '../../ssh/data/ssh_pool.dart';
import '../../ssh/domain/ssh_prompter.dart';
import '../domain/fs_handle.dart';

/// Opens SFTP on a pooled connection (shared with terminals on the same host).
FsOpener sshFsOpener(SshPool pool, SshPrompter Function() prompter, String connectionId) => () async {
      final lease = await pool.acquire(connectionId, prompter());
      final fs = SftpFileSystem(lease.client);
      return FsHandle(
        fs,
        done: lease.done,
        release: () {
          fs.close();
          lease.release();
        },
      );
    };
