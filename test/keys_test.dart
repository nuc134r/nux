import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nux/features/identities/domain/key_generator.dart';
import 'package:nux/features/identities/domain/key_import.dart';
import 'package:nux/features/identities/domain/key_material.dart';

// Keys are generated here with the real tools (ssh-keygen, openssl, puttygen) into a temp dir and
// thrown away: no private keys are committed. Tests whose tool is missing are skipped.
bool _has(String tool) => Process.runSync('sh', ['-c', 'command -v $tool']).exitCode == 0;

final _sshKeygen = _has('ssh-keygen');
final _openssl = _has('openssl');
final _puttygen = _has('puttygen');

late Directory _dir;

String _run(String exe, List<String> args) {
  final r = Process.runSync(exe, args);
  if (r.exitCode != 0) fail('$exe ${args.join(' ')}: ${r.stderr}');
  return '${r.stdout}';
}

String _read(String name) => File('${_dir.path}/$name').readAsStringSync();

/// Creates a key with ssh-keygen and returns its file name.
String _keygen(String name, List<String> type, {String pass = ''}) {
  _run('ssh-keygen', ['-q', ...type, '-N', pass, '-C', 'test@example.com', '-f', '${_dir.path}/$name']);
  return name;
}

String _copy(String from, String to) {
  File('${_dir.path}/$from').copySync('${_dir.path}/$to');
  return to;
}

void main() {
  setUpAll(() => _dir = Directory.systemTemp.createTempSync('nux-keys-'));
  tearDownAll(() => _dir.deleteSync(recursive: true));

  const types = {
    'ed25519': ['-t', 'ed25519'],
    'ecdsa256': ['-t', 'ecdsa', '-b', '256'],
    'ecdsa384': ['-t', 'ecdsa', '-b', '384'],
    'ecdsa521': ['-t', 'ecdsa', '-b', '521'],
    'rsa': ['-t', 'rsa', '-b', '2048'],
  };

  group('OpenSSH keys from ssh-keygen', skip: !_sshKeygen, () {
    for (final MapEntry(key: name, value: type) in types.entries) {
      test(name, () {
        final file = _keygen(name, type);
        final key = importPrivateKey(_read(file));
        final pub = _read('$file.pub').trim();
        expect(key.publicLine(), pub);
        expect(key.comment, 'test@example.com');

        final sha = _run('ssh-keygen', ['-l', '-f', '${_dir.path}/$file.pub']).split(' ')[1];
        expect(sha256Fingerprint(key.publicBlob), sha);
        final md5 = _run('ssh-keygen', ['-l', '-E', 'md5', '-f', '${_dir.path}/$file.pub']).split(' ')[1];
        expect(md5Fingerprint(key.publicBlob), md5);
        final art = _run('ssh-keygen', ['-lv', '-f', '${_dir.path}/$file.pub']).trim().split('\n').skip(1).join('\n');
        expect(randomArt(key.publicBlob), art);
        expect(key.bits, int.parse(_run('ssh-keygen', ['-l', '-f', '${_dir.path}/$file.pub']).split(' ')[0]));
      });
    }

    test('passphrase-protected', () {
      final file = _keygen('enc', ['-t', 'ed25519'], pass: 'correct horse');
      final text = _read(file);
      expect(isKeyEncrypted(text), isTrue);
      expect(() => importPrivateKey(text), throwsA(isA<KeyImportException>().having((e) => e.error, 'error', KeyImportError.needsPassphrase)));
      expect(() => importPrivateKey(text, passphrase: 'nope'),
          throwsA(isA<KeyImportException>().having((e) => e.error, 'error', KeyImportError.wrongPassphrase)));
      expect(importPrivateKey(text, passphrase: 'correct horse').publicLine(), _read('$file.pub').trim());
    });
  });

  group('PEM and PKCS#8', skip: !_sshKeygen, () {
    for (final name in ['rsa', 'ecdsa256', 'ecdsa384']) {
      test('$name as PEM', () {
        final file = _copy(_keygen('$name-src', types[name]!), '$name.pem');
        _run('ssh-keygen', ['-q', '-p', '-m', 'PEM', '-N', '', '-f', '${_dir.path}/$file']);
        final text = _read(file);
        expect(detectKeyFormat(text), name == 'rsa' ? KeyFormat.pkcs1Rsa : KeyFormat.sec1Ec);
        expect(importPrivateKey(text).publicLine('x'), (_read('$name-src.pub').trim().split(' ').take(2).toList()..add('x')).join(' '));
      });
    }

    for (final name in ['rsa', 'ecdsa256', 'ecdsa521']) {
      test('$name as PKCS#8, plain and encrypted', skip: !_openssl, () {
        final file = _copy(_keygen('$name-p8src', types[name]!), '$name.p8');
        _run('ssh-keygen', ['-q', '-p', '-m', 'PKCS8', '-N', '', '-f', '${_dir.path}/$file']);
        final want = _read('$name-p8src.pub').trim().split(' ').take(2).join(' ');
        String public(KeyMaterial k) => k.publicLine('').trim();

        final plain = _read(file);
        expect(detectKeyFormat(plain), KeyFormat.pkcs8);
        expect(public(importPrivateKey(plain)), want);

        final enc = '${_dir.path}/$name.p8enc';
        _run('openssl', ['pkcs8', '-topk8', '-v2', 'aes-256-cbc', '-passout', 'pass:s3cret', '-in', '${_dir.path}/$file', '-out', enc]);
        final encrypted = File(enc).readAsStringSync();
        expect(detectKeyFormat(encrypted), KeyFormat.pkcs8Encrypted);
        expect(() => importPrivateKey(encrypted, passphrase: 'wrong'), throwsA(isA<KeyImportException>()));
        expect(public(importPrivateKey(encrypted, passphrase: 's3cret')), want);
      });
    }
  });

  test('ed25519 as PKCS#8 (openssl), plain and encrypted', skip: !_openssl, () {
    final file = '${_dir.path}/ed.p8';
    _run('openssl', ['genpkey', '-algorithm', 'ed25519', '-out', file]);
    final der = Process.runSync('openssl', ['pkey', '-in', file, '-pubout', '-outform', 'DER'], stdoutEncoding: null).stdout as List<int>;
    final raw = der.sublist(der.length - 32);
    final want = formatPublicLine(
      Uint8List.fromList([0, 0, 0, 11, ...'ssh-ed25519'.codeUnits, 0, 0, 0, 32, ...raw]),
      '',
    );
    expect(importPrivateKey(File(file).readAsStringSync()).publicLine(''), want);
    _run('openssl', ['pkcs8', '-topk8', '-v2', 'aes-128-cbc', '-v2prf', 'hmacWithSHA256', '-passout', 'pass:pw', '-in', file, '-out', '$file.enc']);
    expect(importPrivateKey(File('$file.enc').readAsStringSync(), passphrase: 'pw').publicLine(''), want);
  });

  group('PuTTY keys', skip: !(_sshKeygen && _puttygen), () {
    for (final name in ['ed25519', 'ecdsa256', 'rsa']) {
      for (final version in [2, 3]) {
        test('$name, ppk v$version, plain and encrypted', () {
          final src = _keygen('$name-ppksrc$version', types[name]!);
          final want = _read('$src.pub').trim().split(' ').take(2).join(' ');
          File('${_dir.path}/pass').writeAsStringSync('putty pass\n');

          final plain = '${_dir.path}/$name-$version.ppk';
          _run('puttygen', ['${_dir.path}/$src', '-O', 'private', '-o', plain, '--ppk-param', 'version=$version']);
          final key = importPrivateKey(File(plain).readAsStringSync());
          expect(key.publicLine('').trim(), want);
          expect(key.comment, 'test@example.com');

          final enc = '${_dir.path}/$name-$version-enc.ppk';
          _run('puttygen', [
            '${_dir.path}/$src', '-O', 'private', '-o', enc, '--ppk-param', 'version=$version',
            '--new-passphrase', '${_dir.path}/pass',
            if (version == 3) ...['--ppk-param', 'memory=1024,passes=2'],
          ]);
          final text = File(enc).readAsStringSync();
          expect(isKeyEncrypted(text), isTrue);
          expect(() => importPrivateKey(text, passphrase: 'nope'),
              throwsA(isA<KeyImportException>().having((e) => e.error, 'error', KeyImportError.wrongPassphrase)));
          expect(importPrivateKey(text, passphrase: 'putty pass').publicLine('').trim(), want);
        });
      }
    }
  });

  group('generated keys', () {
    for (final alg in KeyAlgorithm.values.where((a) => a != KeyAlgorithm.rsa4096)) {
      test('${alg.name} is read back by ssh-keygen, with and without a passphrase', skip: !_sshKeygen, () async {
        final key = await generateKey(alg, comment: 'nux@test');
        expect(key.algorithm, alg.sshName);
        expect(key.bits, alg.bits);

        final plain = File('${_dir.path}/gen-${alg.name}')..writeAsStringSync(key.toOpenSsh());
        Process.runSync('chmod', ['600', plain.path]);
        expect(_run('ssh-keygen', ['-y', '-f', plain.path]).trim(), key.publicLine());

        final enc = File('${_dir.path}/gen-${alg.name}-enc')..writeAsStringSync(key.toOpenSsh(passphrase: 'pw'));
        Process.runSync('chmod', ['600', enc.path]);
        expect(_run('ssh-keygen', ['-y', '-P', 'pw', '-f', enc.path]).trim(), key.publicLine());
        expect(importPrivateKey(enc.readAsStringSync(), passphrase: 'pw').publicLine(), key.publicLine());
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  group('detection and errors', () {
    test('a public key line is recognised as such', () {
      const line = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl user@example.com';
      expect(PublicKeyLine.tryParse(line)?.comment, 'user@example.com');
      expect(() => importPrivateKey(line), throwsA(isA<KeyImportException>().having((e) => e.error, 'error', KeyImportError.publicKeyOnly)));
    });

    test('garbage is invalid', () {
      expect(detectKeyFormat('hello'), isNull);
      expect(() => importPrivateKey('hello'), throwsA(isA<KeyImportException>().having((e) => e.error, 'error', KeyImportError.invalid)));
    });

    test('withComment keeps the key', () async {
      final key = await generateKey(KeyAlgorithm.ed25519, comment: 'a');
      final renamed = key.withComment('b');
      expect(renamed.comment, 'b');
      expect(renamed.publicBlob, key.publicBlob);
    });
  });
}
