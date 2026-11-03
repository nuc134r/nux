import 'dart:convert';
import 'dart:typed_data';

import 'package:nux_backend/nux_backend.dart';
import 'package:test/test.dart';

/// Behaviour every [FileSystem] must have. Run it with a fresh, empty, writable [root] per test.
void fileSystemContract(String name, Future<(FileSystem fs, String root)> Function() create) {
  group('$name contract', () {
    late FileSystem fs;
    late String root;
    setUp(() async => (fs, root) = await create());

    String at(String p) => posix.join(root, p);
    Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

    test('write, list, stat, read', () async {
      await fs.writeBytes(at('a.txt'), bytes('hello'));
      await fs.createDirectory(at('sub'));
      final entries = await fs.list(root);
      expect(entries.map((e) => e.name).toSet(), {'a.txt', 'sub'});
      final a = await fs.stat(at('a.txt'));
      expect(a.type, FileType.file);
      expect(a.size, 5);
      expect(a.mode, isNotNull);
      expect((await fs.stat(at('sub'))).isBrowsable, isTrue);
      expect(utf8.decode(await fs.readBytes(at('a.txt'))), 'hello');
    });

    test('streams with offsets resume reads and writes', () async {
      await fs.writeStream(at('s.bin'), Stream.fromIterable([bytes('0123'), bytes('4567')]));
      var progress = 0;
      await fs.writeStream(at('s.bin'), Stream.value(bytes('89')), offset: 8, onProgress: (n) => progress = n);
      expect(progress, 2);
      expect(utf8.decode(await fs.readBytes(at('s.bin'))), '0123456789');
      final tail = await fs.openRead(at('s.bin'), start: 6).expand((c) => c).toList();
      expect(utf8.decode(tail), '6789');
    });

    test('rename refuses to overwrite', () async {
      await fs.writeBytes(at('x'), bytes('1'));
      await fs.writeBytes(at('y'), bytes('2'));
      await expectLater(fs.rename(at('x'), at('y')),
          throwsA(isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.alreadyExists)));
      await fs.rename(at('x'), at('z'));
      expect((await fs.list(root)).map((e) => e.name).toSet(), {'y', 'z'});
    });

    test('recursive create and delete', () async {
      await fs.createDirectory(at('d/e/f'), recursive: true);
      await fs.writeBytes(at('d/e/f/g.txt'), bytes('g'));
      await expectLater(fs.delete(at('d')), throwsA(isA<BackendException>()));
      await fs.delete(at('d'), recursive: true);
      await expectLater(fs.stat(at('d')),
          throwsA(isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.notFound)));
    });

    test('chmod', () async {
      await fs.writeBytes(at('m'), bytes(''));
      await fs.setMode(at('m'), 0x1c0); // 0700
      expect((await fs.stat(at('m'))).mode, 0x1c0);
    });

    test('missing paths are notFound', () async {
      await expectLater(fs.list(at('nope')),
          throwsA(isA<BackendException>().having((e) => e.kind, 'kind', BackendErrorKind.notFound)));
    });
  });
}
