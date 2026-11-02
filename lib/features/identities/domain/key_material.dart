import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/digests/md5.dart';
import 'package:pointycastle/digests/sha256.dart';

import 'ssh_wire.dart';

/// Key algorithms nux can generate.
enum KeyAlgorithm {
  ed25519('ssh-ed25519', 256),
  ecdsaP256('ecdsa-sha2-nistp256', 256),
  ecdsaP384('ecdsa-sha2-nistp384', 384),
  ecdsaP521('ecdsa-sha2-nistp521', 521),
  rsa3072('ssh-rsa', 3072),
  rsa4096('ssh-rsa', 4096);

  const KeyAlgorithm(this.sshName, this.bits);

  final String sshName;
  final int bits;
}

/// A private key in memory, in one of the forms OpenSSH writes (so it can be saved as an OpenSSH
/// private key whatever format it was imported from).
class KeyMaterial {
  KeyMaterial(this.pair);

  final OpenSSHKeyPair pair;

  /// `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ssh-rsa`, …
  String get algorithm => pair.name;

  String get comment => switch (pair) {
        final OpenSSHEd25519KeyPair k => k.comment,
        final OpenSSHEcdsaKeyPair k => k.comment,
        final OpenSSHRsaKeyPair k => k.comment,
        _ => '',
      };

  Uint8List get publicBlob => pair.toPublicKey().encode();

  int get bits => keyBits(publicBlob);

  /// Same key with another comment.
  KeyMaterial withComment(String comment) => KeyMaterial(switch (pair) {
        final OpenSSHEd25519KeyPair k => OpenSSHEd25519KeyPair(k.publicKey, k.privateKey, comment),
        final OpenSSHEcdsaKeyPair k => OpenSSHEcdsaKeyPair(k.curveId, k.q, k.d, comment),
        final OpenSSHRsaKeyPair k => OpenSSHRsaKeyPair(k.n, k.e, k.d, k.iqmp, k.p, k.q, comment),
        _ => throw UnsupportedError('Unsupported key ${pair.runtimeType}'),
      });

  /// The `authorized_keys` line.
  String publicLine([String? comment]) => formatPublicLine(publicBlob, comment ?? this.comment);

  /// OpenSSH private key file contents, encrypted with [passphrase] when it is not empty.
  String toOpenSsh({String? passphrase}) => pair.toPem(passphrase: passphrase);
}

String formatPublicLine(Uint8List blob, String comment) {
  final type = SSHHostKey.getType(blob);
  final line = '$type ${base64.encode(blob)}';
  return comment.trim().isEmpty ? line : '$line ${comment.trim()}';
}

/// A parsed `authorized_keys` / `.pub` line.
class PublicKeyLine {
  const PublicKeyLine(this.type, this.blob, this.comment);

  final String type;
  final Uint8List blob;
  final String comment;

  /// Parses `type base64 [comment]`; null when the line is not a public key.
  static PublicKeyLine? tryParse(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    try {
      final blob = base64.decode(parts[1]);
      if (SshWireReader(blob).readUtf8() != parts[0]) return null;
      return PublicKeyLine(parts[0], blob, parts.skip(2).join(' '));
    } catch (_) {
      return null;
    }
  }
}

/// `SHA256:…` as printed by `ssh-keygen -l` (base64 without padding).
String sha256Fingerprint(Uint8List blob) =>
    'SHA256:${base64.encode(SHA256Digest().process(blob)).replaceAll('=', '')}';

/// `MD5:aa:bb:…` as printed by `ssh-keygen -l -E md5`.
String md5Fingerprint(Uint8List blob) =>
    'MD5:${MD5Digest().process(blob).map((b) => b.toRadixString(16).padLeft(2, '0')).join(':')}';

/// Key size in bits from a public key blob (RSA modulus, curve size, 256 for Ed25519).
int keyBits(Uint8List blob) {
  final r = SshWireReader(blob);
  final type = r.readUtf8();
  return switch (type) {
    'ssh-ed25519' => 256,
    'ssh-rsa' => () {
        r.readMpint(); // e
        return r.readMpint().bitLength;
      }(),
    'ecdsa-sha2-nistp256' => 256,
    'ecdsa-sha2-nistp384' => 384,
    'ecdsa-sha2-nistp521' => 521,
    _ => 0,
  };
}

/// Short display name of a key type: "ED25519", "ECDSA", "RSA".
String keyTypeLabel(String algorithm) => switch (algorithm) {
      'ssh-ed25519' => 'ED25519',
      'ssh-rsa' => 'RSA',
      final a when a.startsWith('ecdsa-') => 'ECDSA',
      final a => a.toUpperCase(),
    };

/// The "randomart" picture `ssh-keygen -lv` draws for a key (the drunken bishop walk over its
/// SHA-256 fingerprint), so a key can be recognised at a glance.
String randomArt(Uint8List blob) {
  const width = 17, height = 9;
  const symbols = ' .o+=*BOX@%&#/^SE';
  final field = List.generate(width, (_) => List.filled(height, 0));
  var x = width ~/ 2, y = height ~/ 2;
  for (final byte in SHA256Digest().process(blob)) {
    var b = byte;
    for (var i = 0; i < 4; i++) {
      x += (b & 1) != 0 ? 1 : -1;
      y += (b & 2) != 0 ? 1 : -1;
      x = x.clamp(0, width - 1);
      y = y.clamp(0, height - 1);
      if (field[x][y] < symbols.length - 3) field[x][y]++;
      b >>= 2;
    }
  }
  field[width ~/ 2][height ~/ 2] = symbols.length - 2; // S
  field[x][y] = symbols.length - 1; // E

  String frame(String label) {
    final inner = label.length > width ? label.substring(0, width) : label;
    final left = (width - inner.length) ~/ 2;
    return '+${'-' * left}$inner${'-' * (width - inner.length - left)}+';
  }

  final out = StringBuffer()..writeln(frame('[${keyTypeLabel(SshWireReader(blob).readUtf8())} ${keyBits(blob)}]'));
  for (var row = 0; row < height; row++) {
    out
      ..write('|')
      ..write([for (var col = 0; col < width; col++) symbols[field[col][row]]].join())
      ..writeln('|');
  }
  out.write(frame('[SHA256]'));
  return out.toString();
}
