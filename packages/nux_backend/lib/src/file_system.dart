import 'dart:typed_data';

enum FileType { file, directory, link, other }

/// One directory entry, or the result of [FileSystem.stat].
class FileEntry {
  const FileEntry({
    required this.path,
    required this.type,
    this.size = 0,
    this.modified,
    this.mode,
    this.linkTarget,
  });

  /// Absolute path in the backend's own syntax (POSIX for SSH and Termux).
  final String path;
  final FileType type;

  /// Size in bytes (0 for directories).
  final int size;
  final DateTime? modified;

  /// POSIX permission bits (e.g. 0o644), when the backend reports them.
  final int? mode;

  /// Where a symbolic link points, when known.
  final String? linkTarget;

  String get name {
    final trimmed = path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final i = trimmed.lastIndexOf('/');
    return i < 0 ? trimmed : trimmed.substring(i + 1);
  }

  bool get isDirectory => type == FileType.directory;

  /// Hidden by convention (dot files).
  bool get isHidden => name.startsWith('.') && name != '.' && name != '..';

  @override
  String toString() => 'FileEntry($path, ${type.name}, $size)';
}

/// Files of a backend. Paths are absolute.
abstract interface class FileSystem {
  /// The directory a new file browser opens in (the user's home on SSH).
  Future<String> home();

  /// Entries of [directory] without `.` and `..`, in no particular order.
  Future<List<FileEntry>> list(String directory);

  /// Throws [BackendException] with [BackendErrorKind.notFound] when [path] does not exist.
  Future<FileEntry> stat(String path);

  Future<Uint8List> readBytes(String path);

  /// Streams a file in chunks; [onProgress] gets the bytes read so far.
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress});

  /// Replaces the file's contents (creates it when missing).
  Future<void> writeBytes(String path, Uint8List bytes);

  Future<void> createDirectory(String path, {bool recursive = false});

  Future<void> rename(String from, String to);

  /// Deletes a file, or a directory with [recursive] (otherwise it must be empty).
  Future<void> delete(String path, {bool recursive = false});

  Future<void> setMode(String path, int mode);
}
