import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'errors.dart';
import 'file_system.dart';

/// [FileSystem] over `dart:io`, rooted at [home] (app storage on the local backend; temp dirs in tests).
class LocalFileSystem implements FileSystem {
  LocalFileSystem(this._home);

  final String _home;

  @override
  Future<String> home() async => _home;

  @override
  Future<List<FileEntry>> list(String directory) => _guard(directory, () async {
        final dir = io.Directory(directory);
        if (!await dir.exists()) {
          throw BackendException(
            await io.File(directory).exists() ? BackendErrorKind.notADirectory : BackendErrorKind.notFound,
            'Not a directory',
            path: directory,
          );
        }
        return [await for (final e in dir.list(followLinks: false)) await _entry(e.path)];
      });

  @override
  Future<FileEntry> stat(String path) => _guard(path, () async {
        if (io.FileSystemEntity.typeSync(path, followLinks: false) == io.FileSystemEntityType.notFound) {
          throw BackendException(BackendErrorKind.notFound, 'No such file', path: path);
        }
        return _entry(path);
      });

  Future<FileEntry> _entry(String path) async {
    final link = await io.FileSystemEntity.isLink(path);
    final s = await io.FileStat.stat(path);
    final type = link
        ? FileType.link
        : switch (s.type) {
            io.FileSystemEntityType.directory => FileType.directory,
            io.FileSystemEntityType.file => FileType.file,
            _ => FileType.other,
          };
    return FileEntry(
      path: path,
      type: type,
      size: s.type == io.FileSystemEntityType.directory ? 0 : s.size,
      modified: s.modified,
      mode: s.mode & 0x1ff,
      linkTarget: link ? await io.Link(path).target() : null,
      targetIsDirectory: link && s.type == io.FileSystemEntityType.directory,
    );
  }

  @override
  Future<Uint8List> readBytes(String path) => _guard(path, () => io.File(path).readAsBytes());

  @override
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress}) async* {
    var read = 0;
    try {
      await for (final chunk in io.File(path).openRead(start)) {
        read += chunk.length;
        onProgress?.call(read);
        yield chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
      }
    } on io.FileSystemException catch (e) {
      throw _map(e, path);
    }
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => _guard(path, () => io.File(path).writeAsBytes(bytes, flush: true));

  @override
  Future<void> writeStream(String path, Stream<List<int>> data, {int offset = 0, void Function(int written)? onProgress}) =>
      _guard(path, () async {
        final file = await io.File(path).open(mode: offset == 0 ? io.FileMode.write : io.FileMode.append);
        try {
          if (offset > 0) await file.setPosition(offset);
          var written = 0;
          await for (final chunk in data) {
            await file.writeFrom(chunk);
            written += chunk.length;
            onProgress?.call(written);
          }
          await file.flush();
        } finally {
          await file.close();
        }
      });

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) =>
      _guard(path, () => io.Directory(path).create(recursive: recursive));

  @override
  Future<void> rename(String from, String to) => _guard(from, () async {
        if (io.FileSystemEntity.typeSync(to, followLinks: false) != io.FileSystemEntityType.notFound) {
          throw BackendException(BackendErrorKind.alreadyExists, 'Already exists', path: to);
        }
        if (io.FileSystemEntity.typeSync(from, followLinks: false) == io.FileSystemEntityType.directory) {
          await io.Directory(from).rename(to);
        } else {
          await io.File(from).rename(to);
        }
      });

  @override
  Future<void> delete(String path, {bool recursive = false}) => _guard(path, () async {
        final type = io.FileSystemEntity.typeSync(path, followLinks: false);
        if (type == io.FileSystemEntityType.notFound) {
          throw BackendException(BackendErrorKind.notFound, 'No such file', path: path);
        }
        if (type == io.FileSystemEntityType.directory) {
          final dir = io.Directory(path);
          if (!recursive && await dir.list().isEmpty == false) {
            throw BackendException(BackendErrorKind.notEmpty, 'Directory not empty', path: path);
          }
          await dir.delete(recursive: recursive);
        } else {
          await io.File(path).delete();
        }
      });

  @override
  Future<void> setMode(String path, int mode) => _guard(path, () async {
        final r = await io.Process.run('chmod', [mode.toRadixString(8), path]);
        if (r.exitCode != 0) throw BackendException(BackendErrorKind.permissionDenied, '${r.stderr}', path: path);
      });

  Future<T> _guard<T>(String path, Future<T> Function() body) async {
    try {
      return await body();
    } on io.FileSystemException catch (e) {
      throw _map(e, path);
    }
  }

  BackendException _map(io.FileSystemException e, String path) {
    final kind = switch (e.osError?.errorCode) {
      2 => BackendErrorKind.notFound,
      13 || 1 => BackendErrorKind.permissionDenied,
      17 => BackendErrorKind.alreadyExists,
      20 => BackendErrorKind.notADirectory,
      21 => BackendErrorKind.isADirectory,
      39 || 66 => BackendErrorKind.notEmpty,
      _ => BackendErrorKind.other,
    };
    return BackendException(kind, e.osError?.message ?? e.message, path: path, cause: e);
  }
}
