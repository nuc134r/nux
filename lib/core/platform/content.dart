import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nux_backend/nux_backend.dart';

/// A file of another app, by content URI.
class ContentItem {
  const ContentItem({required this.uri, required this.name, required this.size, this.mime});

  factory ContentItem.fromMap(Map<Object?, Object?> m) => ContentItem(
    uri: m['uri']! as String,
    name: m['name'] as String? ?? 'file',
    size: (m['size'] as num?)?.toInt() ?? -1,
    mime: m['mime'] as String?,
  );

  final String uri;

  /// The file name; for a picked folder, the path inside it (`photos/2024/a.jpg`).
  final String name;

  /// -1 when the other app does not say.
  final int size;
  final String? mime;
}

enum IncomingAction { view, edit, send }

/// What another app handed to nux: files to open (view / edit) or to upload (send), or shared text.
class Incoming {
  const Incoming(this.action, this.items, {this.text, this.writable = false});

  final IncomingAction action;
  final List<ContentItem> items;
  final String? text;

  /// The other app lets nux write the file back.
  final bool writable;
}

/// A folder picked on the device: its name and every file in it.
class PickedFolder {
  const PickedFolder(this.name, this.files);

  final String name;
  final List<ContentItem> files;
}

/// Reads and writes other apps' files (Android content URIs) and receives "Open with" / "Share to" nux.
/// Off Android there are none: [incoming] never fires.
class ContentFiles {
  ContentFiles([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('nux/content') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') await _take();
    });
  }

  final MethodChannel _channel;
  final _incoming = StreamController<Incoming>.broadcast();

  /// Files and text from other apps, as they arrive (call [start] once a listener is there).
  Stream<Incoming> get incoming => _incoming.stream;

  /// Picks up what arrived before anyone listened (the intent that started the app).
  Future<void> start() => _take();

  Future<void> _take() async {
    final List<Object?> list;
    try {
      list = await _channel.invokeMethod<List<Object?>>('take') ?? const [];
    } on MissingPluginException {
      return;
    }
    for (final m in list.cast<Map<Object?, Object?>>()) {
      _incoming.add(
        Incoming(
          IncomingAction.values.byName(m['action']! as String),
          [for (final i in (m['items'] as List? ?? const []).cast<Map<Object?, Object?>>()) ContentItem.fromMap(i)],
          text: m['text'] as String?,
          writable: m['writable'] == true,
        ),
      );
    }
  }

  Future<T?> _call<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw BackendException(
        e.code == 'denied' ? BackendErrorKind.permissionDenied : BackendErrorKind.other,
        e.message ?? e.code,
        path: args['uri'] as String?,
        cause: e,
      );
    }
  }

  Future<ContentItem> stat(String uri) async =>
      ContentItem.fromMap(await _call<Map<Object?, Object?>>('stat', {'uri': uri}) ?? {'uri': uri});

  Future<Uint8List> read(String uri) async => await _call<Uint8List>('read', {'uri': uri}) ?? Uint8List(0);

  Future<void> write(String uri, Uint8List bytes) => _call<void>('write', {'uri': uri, 'bytes': bytes});

  /// Streams [uri] from [start] in chunks (for uploads).
  Stream<List<int>> openRead(String uri, {int start = 0}) async* {
    final id = await _call<int>('open', {'uri': uri, 'start': start});
    try {
      while (true) {
        final chunk = await _call<Uint8List>('next', {'id': id});
        if (chunk == null) break;
        yield chunk;
      }
    } finally {
      await _call<void>('close', {'id': id});
    }
  }

  /// Lets the user pick a folder; null when cancelled.
  Future<PickedFolder?> pickFolder() async {
    final m = await _call<Map<Object?, Object?>>('pickTree', const {});
    if (m == null) return null;
    return PickedFolder(m['name']! as String, [
      for (final f in (m['files'] as List).cast<Map<Object?, Object?>>()) ContentItem.fromMap(f),
    ]);
  }
}

/// One file of another app as a [FileSystem], so the editor can open it like a file on a host.
/// Every path is that file; listing and the rest are not supported.
class ContentFileSystem implements FileSystem {
  ContentFileSystem(this.files, this.item);

  final ContentFiles files;
  final ContentItem item;

  /// Content URIs have no modification time: one fixed value, so "changed elsewhere" is never claimed.
  static final _modified = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<String> home() async => '/';

  @override
  Future<FileEntry> stat(String path) async {
    final now = await files.stat(item.uri);
    return FileEntry(path: path, type: FileType.file, size: now.size, modified: _modified);
  }

  @override
  Future<Uint8List> readBytes(String path) => files.read(item.uri);

  @override
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress}) async* {
    var read = 0;
    await for (final c in files.openRead(item.uri, start: start)) {
      read += c.length;
      onProgress?.call(read);
      yield Uint8List.fromList(c);
    }
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) => files.write(item.uri, bytes);

  Never _unsupported() => throw const BackendException(BackendErrorKind.unsupported, 'Not supported for this file');

  @override
  Future<List<FileEntry>> list(String directory) async => _unsupported();

  @override
  Future<void> writeStream(
    String path,
    Stream<List<int>> data, {
    int offset = 0,
    void Function(int written)? onProgress,
  }) async => _unsupported();

  @override
  Future<void> createDirectory(String path, {bool recursive = false}) async => _unsupported();

  @override
  Future<void> rename(String from, String to) async => _unsupported();

  @override
  Future<void> delete(String path, {bool recursive = false}) async => _unsupported();

  @override
  Future<void> setMode(String path, int mode) async => _unsupported();
}

final contentFilesProvider = Provider<ContentFiles>((ref) => ContentFiles());
