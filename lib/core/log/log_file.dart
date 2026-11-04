import 'dart:convert';
import 'dart:io';

/// The log on disk, so it survives restarts and crashes: lines are written synchronously (nothing waits
/// in a buffer when the app dies). Past [maxBytes] the file moves to `nux.1.log` and a new one starts,
/// so at most about twice that is kept.
class LogFile {
  LogFile(this.directory, {this.maxBytes = 1 << 20}) {
    Directory(directory).createSync(recursive: true);
    _open();
  }

  final String directory;
  final int maxBytes;
  late RandomAccessFile _file;
  int _size = 0;

  File get current => File('$directory/nux.log');
  File get previous => File('$directory/nux.1.log');

  void _open() {
    _file = current.openSync(mode: FileMode.append);
    _size = _file.lengthSync();
  }

  void write(String line) {
    try {
      if (_size > maxBytes) _rotate();
      final bytes = utf8.encode('$line\n');
      _file.writeFromSync(bytes);
      _size += bytes.length;
    } on FileSystemException {
      // A full or read-only disk must not break the app; the in-memory log still has it.
    }
  }

  void _rotate() {
    _file.closeSync();
    if (previous.existsSync()) previous.deleteSync();
    current.renameSync(previous.path);
    _open();
  }

  /// Everything kept, oldest first.
  String read() => [
    for (final f in [previous, current])
      if (f.existsSync()) f.readAsStringSync(),
  ].join();

  void clear() {
    _file.closeSync();
    for (final f in [previous, current]) {
      if (f.existsSync()) f.deleteSync();
    }
    _open();
  }

  void close() => _file.closeSync();
}
