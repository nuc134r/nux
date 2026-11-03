import 'dart:async';

import 'package:nux_backend/nux_backend.dart';

/// A file system in use: release it when done; [done] completes when the connection drops.
class FsHandle {
  FsHandle(this.fs, {required this.release, Future<void>? done, this.drop})
      : done = done ?? Completer<void>().future;

  final FileSystem fs;
  final void Function() release;
  final Future<void> done;

  /// Closes a connection that stopped answering, so the next open connects afresh.
  final void Function()? drop;
}

typedef FsOpener = Future<FsHandle> Function();
