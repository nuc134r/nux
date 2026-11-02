import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart';

import 'key_generator.dart';
import 'key_material.dart';
import 'ssh_wire.dart';

enum KeyImportError {
  /// The key is encrypted and no passphrase was given.
  needsPassphrase,
  wrongPassphrase,

  /// A public key was given where a private key is needed.
  publicKeyOnly,

  /// A known format nux does not read (e.g. a FIDO `sk-` key).
  unsupported,

  /// Not a key at all.
  invalid,
}

class KeyImportException implements Exception {
  const KeyImportException(this.error, [this.detail]);

  final KeyImportError error;
  final String? detail;

  @override
  String toString() => 'KeyImportException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// The formats [importPrivateKey] understands.
enum KeyFormat { openssh, pkcs1Rsa, sec1Ec, pkcs8, pkcs8Encrypted, puttyV2, puttyV3 }

/// Recognises the format of a private key file; null when it is not one nux reads.
KeyFormat? detectKeyFormat(String text) {
  final t = text.trimLeft();
  if (t.startsWith('PuTTY-User-Key-File-2:')) return KeyFormat.puttyV2;
  if (t.startsWith('PuTTY-User-Key-File-3:')) return KeyFormat.puttyV3;
  final header = RegExp(r'-----BEGIN ([A-Z0-9 ]+)-----').firstMatch(t)?.group(1);
  return switch (header) {
    'OPENSSH PRIVATE KEY' => KeyFormat.openssh,
    'RSA PRIVATE KEY' => KeyFormat.pkcs1Rsa,
    'EC PRIVATE KEY' => KeyFormat.sec1Ec,
    'PRIVATE KEY' => KeyFormat.pkcs8,
    'ENCRYPTED PRIVATE KEY' => KeyFormat.pkcs8Encrypted,
    _ => null,
  };
}

/// Whether the key needs a passphrase to be read.
bool isKeyEncrypted(String text) {
  final format = detectKeyFormat(text);
  switch (format) {
    case KeyFormat.openssh || KeyFormat.pkcs1Rsa || KeyFormat.sec1Ec:
      try {
        return SSHKeyPair.isEncryptedPem(text);
      } catch (_) {
        return false;
      }
    case KeyFormat.pkcs8Encrypted:
      return true;
    case KeyFormat.puttyV2 || KeyFormat.puttyV3:
      return RegExp(r'^Encryption:\s*(\S+)', multiLine: true).firstMatch(text)?.group(1) != 'none';
    case KeyFormat.pkcs8 || null:
      return false;
  }
}

/// Reads a private key in any supported format. The comment comes from the file when it has one.
///
/// Throws [KeyImportException].
KeyMaterial importPrivateKey(String text, {String? passphrase}) {
  final pass = passphrase == null || passphrase.isEmpty ? null : passphrase;
  final format = detectKeyFormat(text);
  if (format == null) {
    if (PublicKeyLine.tryParse(text.trim().split('\n').first) != null || text.contains('BEGIN SSH2 PUBLIC KEY')) {
      throw const KeyImportException(KeyImportError.publicKeyOnly);
    }
    throw const KeyImportException(KeyImportError.invalid);
  }
  if (isKeyEncrypted(text) && pass == null) throw const KeyImportException(KeyImportError.needsPassphrase);
  try {
    return switch (format) {
      KeyFormat.openssh || KeyFormat.pkcs1Rsa || KeyFormat.sec1Ec => _dartssh(text, pass),
      KeyFormat.pkcs8 => _pkcs8(_pemBody(text, 'PRIVATE KEY')),
      KeyFormat.pkcs8Encrypted => _pkcs8(_decryptPkcs8(_pemBody(text, 'ENCRYPTED PRIVATE KEY'), pass!)),
      KeyFormat.puttyV2 || KeyFormat.puttyV3 => _putty(text, pass),
    };
  } on KeyImportException {
    rethrow;
  } on SSHKeyDecryptError {
    throw const KeyImportException(KeyImportError.wrongPassphrase);
  } on UnsupportedError catch (e) {
    throw KeyImportException(KeyImportError.unsupported, e.message);
  } catch (e) {
    // Garbage after decryption almost always means the passphrase was wrong.
    if (pass != null) throw const KeyImportException(KeyImportError.wrongPassphrase);
    throw KeyImportException(KeyImportError.invalid, '$e');
  }
}

KeyMaterial _dartssh(String text, String? passphrase) {
  final pairs = SSHKeyPair.fromPem(text, passphrase);
  if (pairs.isEmpty) throw const KeyImportException(KeyImportError.invalid);
  final pair = pairs.first;
  return switch (pair) {
    final OpenSSHKeyPair k => KeyMaterial(k),
    final RsaPrivateKey k => rsaMaterial(k.n, k.e, k.d, k.p, k.q, ''),
    _ => throw UnsupportedError('Unsupported key ${pair.runtimeType}'),
  };
}

Uint8List _pemBody(String text, String label) {
  final m = RegExp('-----BEGIN $label-----([\\s\\S]*?)-----END $label-----').firstMatch(text);
  if (m == null) throw const KeyImportException(KeyImportError.invalid);
  return base64.decode(m.group(1)!.replaceAll(RegExp(r'\s'), ''));
}

ASN1Object _asn1(Uint8List bytes) => ASN1Parser(bytes).nextObject();

String _oid(ASN1Object o) => (o as ASN1ObjectIdentifier).identifier ?? '';

const _oidRsa = '1.2.840.113549.1.1.1';
const _oidEc = '1.2.840.10045.2.1';
const _oidEd25519 = '1.3.101.112';
const _curves = {'1.2.840.10045.3.1.7': 'nistp256', '1.3.132.0.34': 'nistp384', '1.3.132.0.35': 'nistp521'};

/// PKCS#8 PrivateKeyInfo (RFC 5208 / 5958): RSA, EC or Ed25519.
KeyMaterial _pkcs8(Uint8List der) {
  final seq = _asn1(der) as ASN1Sequence;
  final alg = seq.elements[1] as ASN1Sequence;
  final key = (seq.elements[2] as ASN1OctetString).octets;
  switch (_oid(alg.elements[0])) {
    case _oidRsa:
      final rsa = _asn1(key) as ASN1Sequence;
      BigInt n(int i) => (rsa.elements[i] as ASN1Integer).valueAsBigInteger;
      return rsaMaterial(n(1), n(2), n(3), n(4), n(5), '');
    case _oidEc:
      final curve = _curves[_oid(alg.elements[1])];
      if (curve == null) throw UnsupportedError('Unsupported EC curve');
      final ec = _asn1(key) as ASN1Sequence;
      final d = decodeBigIntUnsigned((ec.elements[1] as ASN1OctetString).octets);
      Uint8List? q;
      for (final e in ec.elements.skip(2)) {
        if (e.tag == 0xa1) q = Uint8List.fromList((_asn1(e.valueBytes()) as ASN1BitString).stringValue);
      }
      return ecdsaMaterial(curve, d, q, '');
    case _oidEd25519:
      final seed = (_asn1(key) as ASN1OctetString).octets;
      return ed25519FromSeed(Uint8List.fromList(seed), '');
    default:
      throw UnsupportedError('Unsupported PKCS#8 key algorithm ${_oid(alg.elements[0])}');
  }
}

/// PKCS#8 EncryptedPrivateKeyInfo with PBES2 (PBKDF2 + AES-CBC), what `openssl pkcs8 -topk8` writes.
Uint8List _decryptPkcs8(Uint8List der, String passphrase) {
  final seq = _asn1(der) as ASN1Sequence;
  final alg = seq.elements[0] as ASN1Sequence;
  final data = (seq.elements[1] as ASN1OctetString).octets;
  if (_oid(alg.elements[0]) != '1.2.840.113549.1.5.13') {
    throw UnsupportedError('Only PBES2-encrypted PKCS#8 keys are supported');
  }
  final params = alg.elements[1] as ASN1Sequence;
  final kdf = params.elements[0] as ASN1Sequence;
  final scheme = params.elements[1] as ASN1Sequence;
  if (_oid(kdf.elements[0]) != '1.2.840.113549.1.5.12') throw UnsupportedError('Only PBKDF2 is supported');
  final kdfParams = kdf.elements[1] as ASN1Sequence;
  final salt = (kdfParams.elements[0] as ASN1OctetString).octets;
  final iterations = (kdfParams.elements[1] as ASN1Integer).intValue;
  var prf = '1.2.840.113549.2.7'; // hmacWithSHA1 (default)
  for (final e in kdfParams.elements.skip(2)) {
    if (e is ASN1Sequence) prf = _oid(e.elements[0]);
  }
  final keyLength = switch (_oid(scheme.elements[0])) {
    '2.16.840.1.101.3.4.1.2' => 16,
    '2.16.840.1.101.3.4.1.22' => 24,
    '2.16.840.1.101.3.4.1.42' => 32,
    final o => throw UnsupportedError('Unsupported cipher $o'),
  };
  final iv = (scheme.elements[1] as ASN1OctetString).octets;
  final digest = switch (prf) {
    '1.2.840.113549.2.7' => SHA1Digest(),
    '1.2.840.113549.2.9' => SHA256Digest(),
    '1.2.840.113549.2.11' => SHA512Digest(),
    final o => throw UnsupportedError('Unsupported PRF $o'),
  } as Digest;
  final key = (PBKDF2KeyDerivator(HMac.withDigest(digest))
        ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, keyLength)))
      .process(Uint8List.fromList(utf8.encode(passphrase)));
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(false, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), Uint8List.fromList(iv)), null));
  return cipher.process(Uint8List.fromList(data));
}

/// PuTTY `.ppk` versions 2 and 3, plain or encrypted (aes256-cbc; Argon2 for v3, SHA-1 for v2).
KeyMaterial _putty(String text, String? passphrase) {
  final lines = const LineSplitter().convert(text.trim());
  final fields = <String, String>{};
  final blocks = <String, String>{};
  for (var i = 0; i < lines.length; i++) {
    final m = RegExp(r'^([A-Za-z0-9-]+):\s*(.*)$').firstMatch(lines[i]);
    if (m == null) continue;
    final name = m.group(1)!, value = m.group(2)!.trim();
    if (name == 'Public-Lines' || name == 'Private-Lines') {
      final count = int.parse(value);
      blocks[name] = lines.sublist(i + 1, i + 1 + count).join();
      i += count;
    } else {
      fields[name] = value;
    }
  }
  final v3 = fields.containsKey('PuTTY-User-Key-File-3');
  final algorithm = fields[v3 ? 'PuTTY-User-Key-File-3' : 'PuTTY-User-Key-File-2'] ?? '';
  final encryption = fields['Encryption'] ?? 'none';
  final comment = fields['Comment'] ?? '';
  final public = base64.decode(blocks['Public-Lines'] ?? '');
  var private = base64.decode(blocks['Private-Lines'] ?? '');
  final mac = fields['Private-MAC'];
  if (mac == null) throw const KeyImportException(KeyImportError.unsupported, 'PuTTY key without a MAC (version 1)');
  if (encryption != 'none' && encryption != 'aes256-cbc') throw UnsupportedError('Unsupported PuTTY cipher $encryption');

  late Uint8List macKey;
  if (v3) {
    if (encryption == 'none') {
      macKey = Uint8List(0);
    } else {
      final type = switch (fields['Key-Derivation']) {
        'Argon2id' => Argon2Parameters.ARGON2_id,
        'Argon2i' => Argon2Parameters.ARGON2_i,
        'Argon2d' => Argon2Parameters.ARGON2_d,
        final k => throw UnsupportedError('Unsupported PuTTY key derivation $k'),
      };
      final argon = Argon2BytesGenerator()
        ..init(Argon2Parameters(
          type,
          _hex(fields['Argon2-Salt']!),
          desiredKeyLength: 80,
          iterations: int.parse(fields['Argon2-Passes']!),
          memory: int.parse(fields['Argon2-Memory']!),
          lanes: int.parse(fields['Argon2-Parallelism']!),
          version: Argon2Parameters.ARGON2_VERSION_13,
        ));
      final out = argon.process(Uint8List.fromList(utf8.encode(passphrase!)));
      private = _aesCbcDecrypt(out.sublist(0, 32), out.sublist(32, 48), private);
      macKey = out.sublist(48, 80);
    }
  } else {
    final pass = utf8.encode(passphrase ?? '');
    if (encryption != 'none') {
      final k1 = SHA1Digest().process(Uint8List.fromList([0, 0, 0, 0, ...pass]));
      final k2 = SHA1Digest().process(Uint8List.fromList([0, 0, 0, 1, ...pass]));
      private = _aesCbcDecrypt(Uint8List.fromList([...k1, ...k2].sublist(0, 32)), Uint8List(16), private);
    }
    macKey = SHA1Digest().process(Uint8List.fromList([...utf8.encode('putty-private-key-file-mac-key'), ...pass]));
  }

  final macData = (SshWireWriter()
        ..writeUtf8(algorithm)
        ..writeUtf8(encryption)
        ..writeUtf8(comment)
        ..writeString(public)
        ..writeString(private))
      .takeBytes();
  final hmac = HMac.withDigest(v3 ? SHA256Digest() : SHA1Digest())..init(KeyParameter(macKey));
  final expected = hmac.process(macData).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  if (expected != mac.toLowerCase()) {
    throw KeyImportException(encryption == 'none' ? KeyImportError.invalid : KeyImportError.wrongPassphrase);
  }

  final pub = SshWireReader(public)..readUtf8();
  final priv = SshWireReader(private);
  switch (algorithm) {
    case 'ssh-rsa':
      final e = pub.readMpint(), n = pub.readMpint();
      final d = priv.readMpint(), p = priv.readMpint(), q = priv.readMpint();
      return rsaMaterial(n, e, d, p, q, comment);
    case 'ssh-ed25519':
      // PuTTY stores the 32-byte seed as a little-endian integer string.
      final raw = priv.readString();
      final seed = Uint8List(32)..setRange(0, raw.length.clamp(0, 32), raw);
      return ed25519FromSeed(seed, comment);
    case 'ecdsa-sha2-nistp256' || 'ecdsa-sha2-nistp384' || 'ecdsa-sha2-nistp521':
      final curve = pub.readUtf8();
      final q = pub.readString();
      return ecdsaMaterial(curve, priv.readMpint(), q, comment);
    default:
      throw UnsupportedError('Unsupported PuTTY key type $algorithm');
  }
}

Uint8List _aesCbcDecrypt(Uint8List key, Uint8List iv, Uint8List data) {
  final cipher = CBCBlockCipher(AESEngine())..init(false, ParametersWithIV(KeyParameter(key), iv));
  final out = Uint8List(data.length);
  for (var off = 0; off < data.length; off += 16) {
    cipher.processBlock(data, off, out, off);
  }
  return out;
}

Uint8List _hex(String s) =>
    Uint8List.fromList([for (var i = 0; i + 1 < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);
