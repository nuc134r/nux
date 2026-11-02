import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed;
import 'package:pointycastle/export.dart';

import 'key_material.dart';
import 'ssh_wire.dart';

/// Generates a new key pair. RSA runs on another isolate (it takes seconds on a phone).
Future<KeyMaterial> generateKey(KeyAlgorithm algorithm, {String comment = ''}) async {
  return switch (algorithm) {
    KeyAlgorithm.ed25519 => _ed25519(comment),
    KeyAlgorithm.ecdsaP256 => _ecdsa('nistp256', ECCurve_secp256r1(), comment),
    KeyAlgorithm.ecdsaP384 => _ecdsa('nistp384', ECCurve_secp384r1(), comment),
    KeyAlgorithm.ecdsaP521 => _ecdsa('nistp521', ECCurve_secp521r1(), comment),
    KeyAlgorithm.rsa3072 || KeyAlgorithm.rsa4096 => await Isolate.run(() => _rsa(algorithm.bits, comment)),
  };
}

KeyMaterial _ed25519(String comment) {
  final key = ed.SigningKey.generate();
  return KeyMaterial(OpenSSHEd25519KeyPair(
    Uint8List.fromList(key.verifyKey.asTypedList),
    Uint8List.fromList(key.asTypedList), // seed + public key, as OpenSSH stores it
    comment,
  ));
}

SecureRandom secureRandom() {
  final random = Random.secure();
  return FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)))));
}

KeyMaterial _ecdsa(String curveId, ECDomainParameters curve, String comment) {
  final generator = ECKeyGenerator()..init(ParametersWithRandom(ECKeyGeneratorParameters(curve), secureRandom()));
  final pair = generator.generateKeyPair();
  final public = pair.publicKey;
  final private = pair.privateKey;
  return KeyMaterial(OpenSSHEcdsaKeyPair(curveId, public.Q!.getEncoded(false), private.d!, comment));
}

KeyMaterial _rsa(int bits, String comment) {
  final generator = RSAKeyGenerator()
    ..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64), secureRandom()));
  final pair = generator.generateKeyPair();
  final private = pair.privateKey;
  return rsaMaterial(private.modulus!, private.publicExponent!, private.privateExponent!, private.p!, private.q!, comment);
}

/// An RSA key from its parts (iqmp is computed).
KeyMaterial rsaMaterial(BigInt n, BigInt e, BigInt d, BigInt p, BigInt q, String comment) =>
    KeyMaterial(OpenSSHRsaKeyPair(n, e, d, q.modInverse(p), p, q, comment));

/// An Ed25519 key from its 32-byte seed.
KeyMaterial ed25519FromSeed(Uint8List seed, String comment) {
  final key = ed.SigningKey.fromSeed(seed);
  return KeyMaterial(OpenSSHEd25519KeyPair(
    Uint8List.fromList(key.verifyKey.asTypedList),
    Uint8List.fromList(key.asTypedList),
    comment,
  ));
}

/// An ECDSA key from its private scalar; the public point is derived when [q] is missing.
KeyMaterial ecdsaMaterial(String curveId, BigInt d, Uint8List? q, String comment) {
  final curve = switch (curveId) {
    'nistp256' => ECCurve_secp256r1(),
    'nistp384' => ECCurve_secp384r1(),
    'nistp521' => ECCurve_secp521r1(),
    _ => throw UnsupportedError('Unsupported curve $curveId'),
  };
  final point = q ?? (curve.G * d)!.getEncoded(false);
  return KeyMaterial(OpenSSHEcdsaKeyPair(curveId, point, d, comment));
}

/// Encodes an unsigned big integer as SSH wire bytes (exposed for tests).
Uint8List mpintBytes(BigInt v) => encodeMpint(v);
