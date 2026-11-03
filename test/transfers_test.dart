import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/files/domain/transfers.dart';
import 'package:nux_backend/nux_backend.dart';

/// Fails reading after [failAfter] bytes once, like a dropped connection.
class FlakyFs extends LocalFileSystem {
  FlakyFs(super.home, {this.failAfter});

  int? failAfter;

  @override
  Stream<Uint8List> openRead(String path, {int start = 0, void Function(int read)? onProgress}) async* {
    var sent = 0;
    await for (final c in super.openRead(path, start: start)) {
      final limit = failAfter;
      if (limit != null && sent + c.length > limit) {
        yield Uint8List.sublistView(c, 0, limit - sent);
        failAfter = null;
        throw const BackendException(BackendErrorKind.disconnected, 'dropped');
      }
      sent += c.length;
      yield c;
    }
  }
}

void main() {
  late Directory remote, local;
  late FlakyFs fs;
  late TransferManager manager;

  setUp(() {
    remote = Directory.systemTemp.createTempSync('nux-remote-');
    local = Directory.systemTemp.createTempSync('nux-local-');
    fs = FlakyFs(remote.path);
    manager = TransferManager(
      opener: (_) => () async => FsHandle(fs, release: () {}),
      downloadsDir: () async => Directory('${local.path}/downloads'),
    );
  });
  tearDown(() {
    manager.dispose();
    remote.deleteSync(recursive: true);
    local.deleteSync(recursive: true);
  });

  test('download, resume after a dropped connection, unique names', () async {
    final data = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    File('${remote.path}/big.bin').writeAsBytesSync(data);
    fs.failAfter = 100000;

    final entry = await fs.stat('${remote.path}/big.bin');
    final t = manager.download('c', entry);
    await manager.idle;
    expect(t.state, TransferState.failed);
    expect(t.done, 100000);

    manager.retry(t);
    await manager.idle;
    expect(t.state, TransferState.done);
    expect(File(t.localPath!).readAsBytesSync(), data);

    final again = manager.download('c', entry);
    await manager.idle;
    expect(again.localPath, endsWith('big (2).bin'));
  });

  test('upload, cancel, resume', () async {
    final src = File('${local.path}/up.txt')..writeAsStringSync('x' * 200000);
    final t = manager.upload('c', remote.path, UploadSource.file(src));
    manager.cancel(t);
    await manager.idle;
    expect(t.state, TransferState.cancelled);
    manager.retry(t);
    await manager.idle;
    expect(t.state, TransferState.done);
    expect(File('${remote.path}/up.txt').readAsStringSync(), 'x' * 200000);
    expect(t.fraction, 1);
    manager.clearFinished();
    expect(manager.transfers, isEmpty);
  });
}
