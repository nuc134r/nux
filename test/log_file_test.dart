import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/core/log/log.dart';
import 'package:nux/core/log/log_file.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nux-log-'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the log survives a restart, with a marker per launch, and hosts masked when shared', () {
    final first = Log()..i('ssh', 'Connecting to build.example.com:22');
    first.persistTo(dir.path);
    first.e('app', 'Uncaught error', StateError('boom'));
    first.dispose(); // "the app died"

    final second = Log()..persistTo(dir.path);
    second.i('app', 'back');
    final shared = second.export();
    expect(shared, contains('[ssh] Connecting to'));
    expect(shared, contains('Bad state: boom'));
    expect(shared, contains('back'));
    expect('nux started'.allMatches(shared), hasLength(2));
    expect(shared, isNot(contains('build.example.com')), reason: 'hosts masked');
    expect(second.export(includeHosts: true), contains('build.example.com'));
    second.dispose();
  });

  test('rotates past the size limit and keeps one previous file', () {
    final file = LogFile(dir.path, maxBytes: 100);
    for (var i = 0; i < 30; i++) {
      file.write('line $i ${'x' * 20}');
    }
    file.close();
    expect(File('${dir.path}/nux.1.log').existsSync(), isTrue);
    final kept = LogFile(dir.path).read();
    expect(kept, contains('line 29'));
    expect(kept, isNot(contains('line 0 ')), reason: 'older files are dropped');
    expect(kept.length, lessThan(400));
  });
}
