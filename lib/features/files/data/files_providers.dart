import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../ssh/data/ssh_providers.dart';
import '../domain/transfers.dart';
import 'ssh_fs.dart';

/// Downloads land in the app's own storage; "Save as…" and "Share" copy them out.
Future<Directory> appDownloadsDir() async => Directory('${(await getApplicationDocumentsDirectory()).path}/Downloads');

final transferManagerProvider = Provider((ref) {
  final manager = TransferManager(
    opener: (connectionId) =>
        sshFsOpener(ref.read(sshPoolProvider), () => ref.read(sshPrompterProvider), connectionId),
    downloadsDir: appDownloadsDir,
  );
  ref.onDispose(manager.dispose);
  return manager;
});
