import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../../core/db/database.dart' show newId;
import 'fs_handle.dart';

enum TransferDirection { upload, download }

enum TransferState { queued, running, done, failed, cancelled }

/// Something to upload: a name, a size and a way to read it from an offset (for resuming).
class UploadSource {
  const UploadSource({required this.name, required this.size, required this.open});

  final String name;
  final int size;
  final Stream<List<int>> Function(int start) open;

  factory UploadSource.file(File file) =>
      UploadSource(name: posix.basename(file.path), size: file.lengthSync(), open: (start) => file.openRead(start));
}

class Transfer {
  Transfer._({
    required this.direction,
    required this.connectionId,
    required this.remotePath,
    required this.total,
    this.source,
  }) : id = newId();

  final String id;
  final TransferDirection direction;
  final String connectionId;
  final String remotePath;
  final UploadSource? source;

  /// Where a download is written (set when it starts).
  String? localPath;
  int total;
  int done = 0;
  TransferState state = TransferState.queued;
  Object? error;
  bool _cancel = false;

  String get name => posix.basename(remotePath);

  bool get active => state == TransferState.queued || state == TransferState.running;

  double? get fraction => total <= 0 ? null : (done / total).clamp(0, 1);
}

/// Queued uploads and downloads, [parallel] at a time. A failed or cancelled transfer can be retried
/// and continues where it stopped.
class TransferManager extends ChangeNotifier {
  TransferManager({required this.opener, required this.downloadsDir, this.parallel = 2});

  final FsOpener Function(String connectionId) opener;
  final Future<Directory> Function() downloadsDir;
  final int parallel;
  final List<Transfer> _transfers = [];
  bool _disposed = false;

  List<Transfer> get transfers => List.unmodifiable(_transfers);

  int get activeCount => _transfers.where((t) => t.active).length;

  Transfer download(String connectionId, FileEntry entry) {
    final t = Transfer._(
      direction: TransferDirection.download,
      connectionId: connectionId,
      remotePath: entry.path,
      total: entry.size,
    );
    _add(t);
    return t;
  }

  /// Downloads every file under [remoteDirectory] into a folder of the same name in the downloads folder,
  /// keeping the layout; returns how many files were queued.
  Future<int> downloadFolder(String connectionId, String remoteDirectory) async {
    final handle = await opener(connectionId)();
    final files = <FileEntry>[];
    try {
      Future<void> walk(String dir) async {
        for (final e in await handle.fs.list(dir)) {
          if (e.type == FileType.directory) {
            await walk(e.path);
          } else if (e.type == FileType.file) {
            files.add(e);
          }
        }
      }

      await walk(remoteDirectory);
    } finally {
      handle.release();
    }
    final dir = await downloadsDir();
    await dir.create(recursive: true);
    final taken = {for (final e in dir.listSync()) posix.basename(e.path)};
    final root = posix.join(dir.path, uniqueName(posix.basename(remoteDirectory), taken));
    await Directory(root).create(recursive: true);
    for (final e in files) {
      final t = Transfer._(
        direction: TransferDirection.download,
        connectionId: connectionId,
        remotePath: e.path,
        total: e.size,
      )..localPath = posix.join(root, posix.relative(e.path, from: remoteDirectory));
      _transfers.add(t);
    }
    _pump();
    return files.length;
  }

  Transfer upload(String connectionId, String remoteDirectory, UploadSource source) {
    final t = Transfer._(
      direction: TransferDirection.upload,
      connectionId: connectionId,
      remotePath: posix.join(remoteDirectory, source.name),
      total: source.size,
      source: source,
    );
    _add(t);
    return t;
  }

  void cancel(Transfer t) {
    if (!t.active) return;
    t._cancel = true;
    if (t.state == TransferState.queued) {
      t.state = TransferState.cancelled;
      _notify();
    }
  }

  /// Runs a failed or cancelled transfer again from where it stopped.
  void retry(Transfer t) {
    if (t.active || t.state == TransferState.done) return;
    t
      ..state = TransferState.queued
      ..error = null
      .._cancel = false;
    _notify();
    _pump();
  }

  void clearFinished() {
    _transfers.removeWhere((t) => !t.active);
    _notify();
  }

  /// Completes when nothing is queued or running (for tests).
  Future<void> get idle async {
    while (_transfers.any((t) => t.active)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void _add(Transfer t) {
    _transfers.add(t);
    _notify();
    _pump();
  }

  void _pump() {
    final running = _transfers.where((t) => t.state == TransferState.running).length;
    for (final t in _transfers.where((t) => t.state == TransferState.queued).take(parallel - running).toList()) {
      t.state = TransferState.running;
      unawaited(_run(t));
    }
    _notify();
  }

  Future<void> _run(Transfer t) async {
    FsHandle? handle;
    try {
      handle = await opener(t.connectionId)();
      if (t.direction == TransferDirection.download) {
        await _download(t, handle.fs);
      } else {
        await _upload(t, handle.fs);
      }
      t.state = t._cancel ? TransferState.cancelled : TransferState.done;
    } catch (e) {
      t
        ..state = t._cancel ? TransferState.cancelled : TransferState.failed
        ..error = e;
    } finally {
      handle?.release();
      _pump();
    }
  }

  Future<void> _download(Transfer t, FileSystem fs) async {
    if (t.localPath == null) {
      final dir = await downloadsDir();
      await dir.create(recursive: true);
      final taken = {for (final e in dir.listSync()) posix.basename(e.path)};
      t.localPath = posix.join(dir.path, uniqueName(t.name, taken));
    }
    final file = File(t.localPath!);
    await file.parent.create(recursive: true);
    final offset = await file.exists() ? await file.length() : 0;
    if (t.total <= 0 || offset == 0) t.total = (await fs.stat(t.remotePath)).size;
    t.done = offset;
    final sink = file.openWrite(mode: offset == 0 ? FileMode.write : FileMode.append);
    try {
      await for (final chunk in fs.openRead(t.remotePath, start: offset)) {
        if (t._cancel) break;
        sink.add(chunk);
        t.done += chunk.length;
        _notify();
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _upload(Transfer t, FileSystem fs) async {
    // A file of an uploaded folder (`photos/2024/a.jpg`): its folders first.
    if (t.source!.name.contains('/')) await fs.createDirectory(posix.dirname(t.remotePath), recursive: true);
    var offset = 0;
    if (t.done > 0) {
      // Resuming: continue after what the server already has.
      try {
        offset = (await fs.stat(t.remotePath)).size.clamp(0, t.total);
      } on BackendException catch (e) {
        if (e.kind != BackendErrorKind.notFound) rethrow;
      }
    }
    t.done = offset;
    _notify();
    final data = t.source!.open(offset).takeWhile((_) => !t._cancel);
    await fs.writeStream(
      t.remotePath,
      data,
      offset: offset,
      onProgress: (n) {
        t.done = offset + n;
        _notify();
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _transfers) {
      t._cancel = true;
    }
    super.dispose();
  }
}
