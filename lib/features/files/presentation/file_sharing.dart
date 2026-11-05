import 'dart:io';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:nux_backend/nux_backend.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/platform/content.dart';
import '../domain/fs_handle.dart';
import '../domain/transfers.dart';

/// Hands a file on a host to another app (the system share sheet): it is fetched into the app's cache first.
Future<void> shareRemoteFile(FsOpener open, String path) async {
  final dir = Directory(posix.join((await getTemporaryDirectory()).path, 'shared'));
  if (dir.existsSync()) dir.deleteSync(recursive: true); // last time's
  await dir.create(recursive: true);
  final local = File(posix.join(dir.path, posix.basename(path)));
  final handle = await open();
  try {
    final sink = local.openWrite();
    try {
      await sink.addStream(handle.fs.openRead(path));
    } finally {
      await sink.close();
    }
  } finally {
    handle.release();
  }
  await SharePlus.instance.share(ShareParams(files: [XFile(local.path)]));
}

/// Shares text as a file named [name] (an unsaved editor's content).
Future<void> shareText(String name, String text) async {
  final dir = Directory(posix.join((await getTemporaryDirectory()).path, 'shared'));
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  await dir.create(recursive: true);
  final local = File(posix.join(dir.path, name))..writeAsStringSync(text);
  await SharePlus.instance.share(ShareParams(files: [XFile(local.path)]));
}

/// Uploads of other apps' files (shared to nux, or a picked folder).
List<UploadSource> contentUploads(ContentFiles files, List<ContentItem> items) => [
  for (final i in items)
    UploadSource(
      name: i.name,
      size: i.size,
      open: (start) => files.openRead(i.uri, start: start),
    ),
];

/// Lets the user pick a folder on the device and lists it as uploads (paths start with the folder's name).
/// Null when cancelled.
Future<List<UploadSource>?> pickFolderUploads(ContentFiles files) async {
  if (Platform.isAndroid) {
    final folder = await files.pickFolder();
    return folder == null ? null : contentUploads(files, folder.files);
  }
  final path = await FilePicker.getDirectoryPath();
  if (path == null) return null;
  final root = Directory(path);
  return [
    for (final f in root.listSync(recursive: true).whereType<File>())
      UploadSource(
        name: posix.join(posix.basename(path), posix.relative(f.path, from: path)),
        size: f.lengthSync(),
        open: (start) => f.openRead(start),
      ),
  ];
}
