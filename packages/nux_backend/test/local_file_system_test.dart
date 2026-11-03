import 'dart:io';

import 'package:nux_backend/nux_backend.dart';
import 'package:test/test.dart';

import 'file_system_contract.dart';

void main() {
  fileSystemContract('LocalFileSystem', () async {
    final dir = Directory.systemTemp.createTempSync('nux-fs-');
    addTearDown(() => dir.deleteSync(recursive: true));
    return (LocalFileSystem(dir.path), dir.path);
  });

  test('path helpers', () {
    expect(pathAncestors('/srv/app/lib'), ['/', '/srv', '/srv/app', '/srv/app/lib']);
    expect(uniqueName('a.txt', {'a.txt', 'a (2).txt'}), 'a (3).txt');
    expect(uniqueName('Makefile', {'Makefile'}), 'Makefile (2)');
    expect(uniqueName('.bashrc', {'.bashrc'}), '.bashrc (2)');
  });
}
