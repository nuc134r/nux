import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nux_backend/nux_backend.dart';

import '../../files/domain/file_listing.dart';
import '../../files/domain/fs_handle.dart';

/// The file changed on the server after it was opened here.
class RemoteChangedException implements Exception {
  const RemoteChangedException();
}

/// A remote file loaded for viewing and editing. Big files load partially first (see [limitFor]).

class RemoteDocument extends ChangeNotifier {
  RemoteDocument({required this._open, required this.path});

  final FsOpener _open;
  final String path;

  bool loading = false;
  Object? error;
  Uint8List? bytes;

  /// Size of the whole file.
  int size = 0;

  /// Modification time when loaded (or last saved), to notice changes made elsewhere.
  DateTime? modified;

  /// Bumped by every [load] (not by [save]), so an editor knows when to take the new content.
  int generation = 0;

  bool saving = false;

  /// Detected from the name, then corrected by the content (a text-named file full of NULs is binary).
  FileKind kind = FileKind.text;

  /// Shown as text even though it looks binary.
  bool forceText = false;

  bool _disposed = false;

  /// Only part of the file is loaded.
  bool get truncated => bytes != null && bytes!.length < size;

  String get name => posix.basename(path);

  String? _text;
  String get text => _text ??= utf8.decode(bytes ?? const [], allowMalformed: true);

  /// What [load] reads by default.
  static int limitFor(FileKind kind) => switch (kind) {
        FileKind.image => 32 << 20,
        FileKind.binary || FileKind.archive => 256 << 10,
        FileKind.text || FileKind.markdown => 2 << 20,
      };

  /// Loads the file; [all] ignores the size limit.
  Future<void> load({bool all = false}) async {
    loading = true;
    error = null;
    _notify();
    FsHandle? handle;
    try {
      handle = await _open();
      final fs = handle.fs;
      final stat = await fs.stat(path);
      size = stat.size;
      modified = stat.modified;
      final named = fileKindByName(path);
      final limit = all ? size : limitFor(named);
      final out = BytesBuilder(copy: false);
      await for (final chunk in fs.openRead(path)) {
        final room = limit - out.length;
        if (room <= 0) break;
        out.add(chunk.length > room ? Uint8List.sublistView(chunk, 0, room) : chunk);
        if (out.length >= limit) break;
      }
      bytes = out.takeBytes();
      _text = null;
      generation++;
      kind = (named == FileKind.text || named == FileKind.markdown) && !forceText && looksBinary(bytes!) ? FileKind.binary : named;
    } catch (e) {
      error = e;
    } finally {
      handle?.release();
      loading = false;
      _notify();
    }
  }

  /// Writes [text] back. Throws [RemoteChangedException] when the file changed on the server since it was
  /// loaded (unless [force]).
  Future<void> save(String text, {bool force = false}) async {
    saving = true;
    _notify();
    FsHandle? handle;
    try {
      handle = await _open();
      final fs = handle.fs;
      if (!force) {
        final now = await fs.stat(path);
        if (now.size != size || now.modified != modified) throw const RemoteChangedException();
      }
      final data = Uint8List.fromList(utf8.encode(text));
      await fs.writeBytes(path, data);
      final after = await fs.stat(path);
      bytes = data;
      _text = text;
      size = after.size;
      modified = after.modified;
    } finally {
      handle?.release();
      saving = false;
      _notify();
    }
  }

  /// Shows a binary-looking file as text anyway.
  void showAsText() {
    forceText = true;
    kind = FileKind.text;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// `00000010  48 65 6c 6c 6f 0a  |Hello.|` lines, 16 bytes each.
String hexLine(Uint8List bytes, int offset) {
  final end = (offset + 16).clamp(0, bytes.length);
  final row = bytes.sublist(offset, end);
  final hex = StringBuffer();
  for (var i = 0; i < 16; i++) {
    hex.write(i < row.length ? row[i].toRadixString(16).padLeft(2, '0') : '  ');
    hex.write(i == 7 ? '  ' : ' ');
  }
  final ascii = String.fromCharCodes(row.map((b) => b >= 32 && b < 127 ? b : 46));
  return '${offset.toRadixString(16).padLeft(8, '0')}  $hex |$ascii|';
}
