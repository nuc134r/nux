import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nux_backend/nux_backend.dart';

import 'file_listing.dart';
import 'fs_handle.dart';

/// State of one file browser tab: where it is, what is there, what is selected.
/// Lives in the tab object, so parking the tab keeps the place and the connection.
class FileBrowser extends ChangeNotifier {
  FileBrowser({required this._open, this._path, this.sort = FileSort.name, this.showHidden = false});

  final FsOpener _open;
  FsHandle? _handle;
  Future<FsHandle>? _opening;

  String? _path;
  List<FileEntry> _all = const [];
  bool loading = false;

  /// What went wrong loading the current folder (a [BackendException] or a connection error).
  Object? error;

  FileSort sort;
  bool descending = false;
  bool showHidden;
  final Set<String> selection = {};
  bool _disposed = false;

  /// Null until the start folder is known.
  String? get path => _path;

  List<FileEntry> get entries => sortEntries(_all, sort: sort, descending: descending, showHidden: showHidden);

  int get hiddenCount => _all.where((e) => e.isHidden).length;

  bool get canGoUp => _path != null && _path != '/';

  bool get selecting => selection.isNotEmpty;

  Future<FileSystem> get fs async => (await _connect()).fs;

  Future<FsHandle> _connect() {
    final h = _handle;
    if (h != null) return Future.value(h);
    return _opening ??= _open().then((h) {
      _handle = h;
      _opening = null;
      h.done.whenComplete(() {
        if (_handle == h) _handle = null;
      });
      return h;
    }, onError: (Object e) {
      _opening = null;
      throw e;
    });
  }

  /// Loads the start folder (the saved one, or the home directory).
  Future<void> start() => _path == null ? _load(null) : refresh();

  Future<void> cd(String path) => _load(path);

  Future<void> up() async {
    if (canGoUp) await _load(posix.dirname(_path!));
  }

  Future<void> refresh() => _load(_path);

  Future<void> _load(String? target) async {
    loading = true;
    error = null;
    _notify();
    try {
      final fs = await this.fs;
      final dir = target ?? await fs.home();
      final list = await fs.list(dir);
      if (dir != _path) selection.clear();
      _path = dir;
      _all = list;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      _notify();
    }
  }

  void setSort(FileSort s) {
    descending = s == sort ? !descending : false;
    sort = s;
    _notify();
  }

  void toggleHidden() {
    showHidden = !showHidden;
    _notify();
  }

  void toggleSelected(FileEntry e) {
    selection.contains(e.path) ? selection.remove(e.path) : selection.add(e.path);
    _notify();
  }

  void selectAll() {
    selection.addAll(entries.map((e) => e.path));
    _notify();
  }

  void clearSelection() {
    selection.clear();
    _notify();
  }

  /// Names in the current folder (for "already exists" checks).
  Set<String> get names => {for (final e in _all) e.name};

  Future<void> mkdir(String name) => _change(() async => (await fs).createDirectory(posix.join(_path!, name)));

  Future<void> rename(FileEntry e, String name) =>
      _change(() async => (await fs).rename(e.path, posix.join(posix.dirname(e.path), name)));

  /// Moves [paths] into [directory].
  Future<void> move(Iterable<String> paths, String directory) => _change(() async {
        final f = await fs;
        for (final p in paths) {
          await f.rename(p, posix.join(directory, posix.basename(p)));
        }
      });

  Future<void> delete(Iterable<String> paths) => _change(() async {
        final f = await fs;
        for (final p in paths) {
          await f.delete(p, recursive: true);
        }
      });

  Future<void> chmod(String path, int mode) => _change(() async => (await fs).setMode(path, mode));

  /// Runs a change, then reloads the folder (also when the change failed half way).
  Future<void> _change(Future<void> Function() body) async {
    try {
      await body();
    } finally {
      selection.clear();
      await refresh();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _handle?.release();
    _opening?.then((h) => h.release(), onError: (_) {});
    super.dispose();
  }
}
