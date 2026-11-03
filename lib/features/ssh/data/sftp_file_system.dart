import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:nux_backend/nux_backend.dart';

/// [FileSystem] over SFTP. The SFTP subsystem is opened on first use.
class SftpFileSystem implements FileSystem {
  SftpFileSystem(this._client);

  final SSHClient _client;
  Future<SftpClient>? _sftp;

  Future<SftpClient> get _s => _sftp ??= _client.sftp();

  Future<void> close() async {
    final s = _sftp;
    _sftp = null;
    if (s != null) await (await s).close();
  }

  @override
  Future<String> home() => _guard('.', () async => (await _s).absolute('.'));

  @override
  Future<List<FileEntry>> list(String directory) => _guard(directory, () async {
        final s = await _s;
        final names = await s.listdir(directory);
        final entries = <FileEntry>[];
        for (final n in names) {
          if (n.filename == '.' || n.filename == '..') continue;
          final path = posix.join(directory, n.filename);
          final (owner, group) = ownerFromLongname(n.longname) ?? (n.attr.userID?.toString(), n.attr.groupID?.toString());
          var entry = _entry(path, n.attr, owner: owner, group: group);
          if (entry.type == FileType.link) {
            // Follow links so "link to a directory" can be browsed; a broken link stays a link.
            try {
              final target = await s.stat(path);
              entry = FileEntry(
                path: path,
                type: FileType.link,
                size: target.size ?? 0,
                modified: entry.modified,
                mode: entry.mode,
                targetIsDirectory: target.isDirectory,
                owner: entry.owner,
                group: entry.group,
              );
            } catch (_) {}
          }
          entries.add(entry);
        }
        return entries;
      });

  @override
  Future<FileEntry> stat(String path) => _guard(path, () async {
        final s = await _s;
        final attrs = await s.stat(path, followLink: false);
        if (!attrs.isSymbolicLink) return _entry(path, attrs);
        String? target;
        var isDir = false;
        try {
          target = await s.readlink(path);
          isDir = (await s.stat(path)).isDirectory;
        } catch (_) {}
        return FileEntry(
          path: path,
          type: FileType.link,
          size: attrs.size ?? 0,
          modified: _time(attrs.modifyTime),
          mode: attrs.mode == null ? null : attrs.mode!.value & 0x1ff,
          linkTarget: target,
          targetIsDirectory: isDir,
          owner: attrs.userID?.toString(),
          group: attrs.groupID?.toString(),
        );
      });

  FileEntry _entry(String path, SftpFileAttrs a, {String? owner, String? group}) => FileEntry(
        path: path,
        type: a.isDirectory
            ? FileType.directory
            : a.isSymbolicLink
                ? FileType.link
                : a.mode?.type == SftpFileType.regularFile || a.mode == null
                    ? FileType.file
                    : FileType.other,
        size: a.isDirectory ? 0 : a.size ?? 0,
        modified: _time(a.modifyTime),
        mode: a.mode == null ? null : a.mode!.value & 0x1ff,
        owner: owner ?? a.userID?.toString(),
        group: group ?? a.groupID?.toString(),
      );

  DateTime? _time(int? seconds) => seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  @override
  Future<Uint8List> readBytes(String path) => _guard(path, () async {
        final f = await (await _s).open(path);
        try {
          return await f.readBytes();
        } finally {
          await f.close();
        }
      });

  @override
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress}) async* {
    SftpFile? f;
    try {
      f = await (await _s).open(path);
      yield* f.read(offset: start, onProgress: onProgress);
    } on SftpStatusError catch (e) {
      throw _map(e, path);
    } finally {
      await f?.close();
    }
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => writeStream(path, Stream.value(bytes));

  @override
  Future<void> writeStream(String path, Stream<List<int>> data, {int offset = 0, void Function(int written)? onProgress}) =>
      _guard(path, () async {
        final mode = offset == 0
            ? SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write
            : SftpFileOpenMode.create | SftpFileOpenMode.write;
        final f = await (await _s).open(path, mode: mode);
        try {
          final writer = f.write(
            // dartssh2 rejects empty chunks (chunkSize 0), e.g. writing an empty file.
            data.where((c) => c.isNotEmpty).map((c) => c is Uint8List ? c : Uint8List.fromList(c)),
            offset: offset,
            onProgress: onProgress,
          );
          await writer.done;
        } finally {
          await f.close();
        }
      });

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) => _guard(path, () async {
        final s = await _s;
        if (!recursive) return s.mkdir(path);
        for (final dir in pathAncestors(path).skip(1)) {
          try {
            if ((await s.stat(dir)).isDirectory) continue;
          } on SftpStatusError catch (e) {
            if (e.code != SftpStatusCode.noSuchFile) rethrow;
          }
          await s.mkdir(dir);
        }
      });

  @override
  Future<void> rename(String from, String to) => _guard(from, () async {
        final s = await _s;
        // SFTP v3 rename fails on an existing target on most servers, but not all: check first.
        try {
          await s.stat(to, followLink: false);
          throw BackendException(BackendErrorKind.alreadyExists, 'Already exists', path: to);
        } on SftpStatusError catch (e) {
          if (e.code != SftpStatusCode.noSuchFile) rethrow;
        }
        await s.rename(from, to);
      });

  @override
  Future<void> delete(String path, {bool recursive = false}) => _guard(path, () async {
        final s = await _s;
        final attrs = await s.stat(path, followLink: false);
        if (!attrs.isDirectory) return s.remove(path);
        if (recursive) {
          for (final n in await s.listdir(path)) {
            if (n.filename == '.' || n.filename == '..') continue;
            await delete(posix.join(path, n.filename), recursive: true);
          }
        }
        await s.rmdir(path);
      });

  @override
  Future<void> setMode(String path, int mode) =>
      _guard(path, () async => (await _s).setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode))));

  Future<T> _guard<T>(String path, Future<T> Function() body) async {
    try {
      return await body();
    } on SftpStatusError catch (e) {
      throw _map(e, path);
    } on SSHError catch (e) {
      throw BackendException(BackendErrorKind.disconnected, '$e', path: path, cause: e);
    }
  }

  BackendException _map(SftpStatusError e, String path) {
    final kind = switch (e.code) {
      SftpStatusCode.noSuchFile => BackendErrorKind.notFound,
      SftpStatusCode.permissionDenied => BackendErrorKind.permissionDenied,
      SftpStatusCode.noConnection || SftpStatusCode.connectionLost => BackendErrorKind.disconnected,
      SftpStatusCode.opUnsupported => BackendErrorKind.unsupported,
      _ => BackendErrorKind.other,
    };
    return BackendException(kind, e.message, path: path, cause: e);
  }
}

/// Owner and group names from an SFTP v3 "longname", which servers format like `ls -l`:
/// `-rw-r--r--    1 alice    staff        1234 Mar  5 10:00 notes.txt`. Null when it does not look so.
(String, String)? ownerFromLongname(String longname) {
  final f = longname.trim().split(RegExp(r'\s+'));
  if (f.length < 5 || !RegExp(r'^[-dlcbps][-rwxsStT]{9}').hasMatch(f[0]) || int.tryParse(f[1]) == null) return null;
  return (f[2], f[3]);
}
