import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/files/domain/fs_handle.dart';
import 'package:nux/features/viewer/domain/remote_document.dart';
import 'package:nux/features/viewer/domain/text_encoding.dart';
import 'package:nux_backend/nux_backend.dart';

void main() {
  test('detects BOMs, UTF-8 and falls back to Latin-1', () {
    Uint8List b(List<int> x) => Uint8List.fromList(x);
    expect(detectEncoding(b(utf8.encode('привет'))), TextEncoding.utf8);
    expect(detectEncoding(b([0xEF, 0xBB, 0xBF, 0x61])), TextEncoding.utf8Bom);
    expect(detectEncoding(b([0xFF, 0xFE, 0x61, 0])), TextEncoding.utf16le);
    expect(detectEncoding(b([0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2])), TextEncoding.latin1, reason: 'cp1251 bytes are not UTF-8');
  });

  test('line endings are found, normalised for editing and restored on save', () {
    final d = decodeText(Uint8List.fromList(utf8.encode('a\r\nb\r\nc')));
    expect((d.text, d.lineEnding), ('a\nb\nc', LineEnding.crlf));
    expect(utf8.decode(encodeText(d.text, TextEncoding.utf8, LineEnding.crlf)), 'a\r\nb\r\nc');
    expect(utf8.decode(encodeText(d.text, TextEncoding.utf8, LineEnding.lf)), 'a\nb\nc');
    expect(decodeText(Uint8List.fromList(utf8.encode('x\ny'))).lineEnding, LineEnding.lf);
  });

  test('every encoding round-trips what it can hold', () {
    const text = 'Привет, ёЁ № — ok\nline 2';
    for (final e in TextEncoding.values.where((e) => e != TextEncoding.latin1)) {
      final bytes = encodeText(text, e, LineEnding.lf);
      expect(decodeText(bytes, encoding: e).text, text, reason: e.label);
    }
    expect(decodeText(encodeText('café', TextEncoding.latin1, LineEnding.lf), encoding: TextEncoding.latin1).text, 'café');
    expect(encodeText('Ж', TextEncoding.latin1, LineEnding.lf), [0x3F], reason: 'unencodable → ?');
    // Known Windows-1251 bytes.
    expect(encodeText('Привет', TextEncoding.windows1251, LineEnding.lf), [0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2]);
  });

  test('a document: reopen in the right encoding, then save as UTF-8 keeping CRLF', () async {
    final dir = Directory.systemTemp.createTempSync('nux-enc-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/old.txt')
      ..writeAsBytesSync(encodeText('Привет\nмир', TextEncoding.windows1251, LineEnding.crlf));
    final doc = RemoteDocument(open: () async => FsHandle(LocalFileSystem(dir.path), release: () {}), path: file.path);
    await doc.load();
    expect(doc.text.contains('Привет'), isFalse, reason: 'not UTF-8: read as ISO 8859-1 first');
    expect(doc.lineEnding, LineEnding.crlf);
    await doc.reopenWith(TextEncoding.windows1251);
    expect(doc.text, 'Привет\nмир');
    doc.saveAs(TextEncoding.utf8);
    expect(doc.formatChanged, isTrue);
    await doc.save(doc.text);
    expect(utf8.decode(file.readAsBytesSync()), 'Привет\r\nмир');
    expect(doc.formatChanged, isFalse);
  });
}
