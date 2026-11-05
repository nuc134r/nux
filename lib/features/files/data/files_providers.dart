import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart' show posix;
import 'package:path_provider/path_provider.dart';

import '../../../core/activity/activity_center.dart';
import '../../../l10n/l10n.dart';
import '../../ssh/data/ssh_providers.dart';
import '../presentation/transfers_sheet.dart';
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
  _reportTransfers(manager, ref.read(activityCenterProvider));
  return manager;
});

/// Each upload and download is an Activity operation (progress, Cancel; Try again when it fails).
void _reportTransfers(TransferManager manager, ActivityCenter center) {
  final entries = Expando<ActivityEntry>();
  manager.addListener(() {
    for (final t in manager.transfers) {
      var e = entries[t];
      // A retried transfer runs again as a new operation.
      if (t.active && (e == null || !e.running)) {
        final l10n = currentL10n.value;
        e = entries[t] = center.start(
          ActivitySource.transfer,
          t.direction == TransferDirection.upload ? l10n.activityUpload(t.name) : l10n.activityDownload(t.name),
          subtitle: posix.dirname(t.remotePath),
          cancel: () => manager.cancel(t),
          open: showTransfersSheet,
        );
      }
      if (e == null || !e.running) continue;
      if (t.active) {
        center.update(e, progress: t.fraction);
      } else {
        final state = switch (t.state) {
          TransferState.done => ActivityState.done,
          TransferState.cancelled => ActivityState.cancelled,
          _ => ActivityState.failed,
        };
        e.retry = state == ActivityState.failed ? () => manager.retry(t) : null;
        center.finish(e, state, subtitle: t.error?.toString(), unread: state == ActivityState.failed);
      }
    }
  });
}
