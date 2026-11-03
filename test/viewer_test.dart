import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/files/domain/file_listing.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/viewer/domain/languages.dart';
import 'package:nux/features/viewer/domain/remote_document.dart';
import 'package:nux_backend/nux_backend.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nux-viewer-'));
  tearDown(() => dir.deleteSync(recursive: true));

  RemoteDocument doc(String name) {
    final d = RemoteDocument(open: () async => FsHandle(LocalFileSystem(dir.path), release: () {}), path: '${dir.path}/$name');
    addTearDown(d.dispose);
    return d;
  }

  test('text loads whole; big text loads partially until asked', () async {
    File('${dir.path}/small.dart').writeAsStringSync('void main() {}\n');
    final small = doc('small.dart');
    await small.load();
    expect(small.kind, FileKind.text);
    expect(small.text, 'void main() {}\n');
    expect(small.truncated, isFalse);

    File('${dir.path}/big.log').writeAsStringSync('x' * (3 << 20));
    final big = doc('big.log');
    await big.load();
    expect(big.truncated, isTrue);
    expect(big.bytes!.length, RemoteDocument.limitFor(FileKind.text));
    await big.load(all: true);
    expect(big.truncated, isFalse);
  });

  test('binary content is detected whatever the name; hex lines', () async {
    File('${dir.path}/data.txt').writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46, 0, 1, 2]);
    final d = doc('data.txt');
    await d.load();
    expect(d.kind, FileKind.binary);
    d.showAsText();
    expect(d.kind, FileKind.text);
    expect(hexLine(Uint8List.fromList('Hello, nux!\n'.codeUnits), 0),
        '00000000  48 65 6c 6c 6f 2c 20 6e  75 78 21 0a              |Hello, nux!.|');
  });

  test('save writes back and refuses to overwrite changes made elsewhere', () async {
    final file = File('${dir.path}/notes.txt')..writeAsStringSync('one\n');
    final d = doc('notes.txt');
    await d.load();
    final generation = d.generation;
    await d.save('two\n');
    expect(file.readAsStringSync(), 'two\n');
    expect(d.generation, generation, reason: 'saving keeps the editor (and its undo history)');

    // Someone else edits the file (different size, so even coarse mtimes notice).
    file.writeAsStringSync('changed elsewhere\n');
    await expectLater(d.save('three\n'), throwsA(isA<RemoteChangedException>()));
    expect(file.readAsStringSync(), 'changed elsewhere\n');
    await d.save('three\n', force: true);
    expect(file.readAsStringSync(), 'three\n');
  });

  test('missing files report an error', () async {
    final d = doc('nope');
    await d.load();
    expect(d.error, isA<BackendException>());
  });

  test('languages', () {
    expect(languageFor('/srv/app/main.dart'), 'dart');
    expect(languageFor('Dockerfile'), 'dockerfile');
    expect(languageFor('.bashrc'), 'bash');
    expect(languageFor('notes.unknownext'), isNull);
    expect(languageFromShebang('#!/usr/bin/env python3'), 'python');
    expect(modeFor('yaml'), isNotNull);
  });
}
