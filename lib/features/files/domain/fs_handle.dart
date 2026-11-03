import 'package:nux_backend/nux_backend.dart';

/// A file system in use: release it when done; [done] completes when the connection drops.
class FsHandle {
  FsHandle(this.fs, {required this.release, Future<void>? done}) : done = done ?? Future<void>.value();

  final FileSystem fs;
  final void Function() release;
  final Future<void> done;
}

typedef FsOpener = Future<FsHandle> Function();
