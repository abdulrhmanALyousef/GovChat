import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'crypto_utils.dart';

/// An RSA key pair produced by [RsaService.generateKeyPair].
class RsaKeyPair {
  final RSAPublicKey publicKey;
  final RSAPrivateKey privateKey;

  const RsaKeyPair({required this.publicKey, required this.privateKey});
}

/// RSA-2048 key generation, OAEP encryption/decryption, and serialization.
///
/// Algorithm choices:
/// - 2048-bit modulus (minimum recommended; increase to 4096 for max security)
/// - Public exponent 65537 (F4 — standard)
/// - OAEP padding with SHA-256 (PKCS#1 v2.2)
class RsaService {
  RsaService._();

  static const int _keyBits = 2048;

  // ── Key generation ──────────────────────────────────────────────────────────

  /// Generate an RSA key pair in a background isolate so the UI stays responsive.
  static Future<RsaKeyPair> generateKeyPair() async {
    // Pass fresh random seed bytes into the isolate so it has its own entropy.
    final seeds = CryptoUtils.randomBytes(64);
    return compute(_generateInIsolate, seeds);
  }

  // ── Encrypt / Decrypt ───────────────────────────────────────────────────────

  /// Encrypt [data] with RSA-OAEP-SHA256 using [publicKey].
  ///
  /// Maximum plaintext size for RSA-2048 with OAEP-SHA256 = 190 bytes.
  /// An AES-256 key (32 bytes) fits comfortably.
  static Uint8List encrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(data);
  }

  /// Decrypt [data] with RSA-OAEP-SHA256 using [privateKey].
  static Uint8List decrypt(Uint8List data, RSAPrivateKey privateKey) {
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    return cipher.process(data);
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  /// Serialize public key to a Firestore-friendly map (`{n, e}` as base64).
  static Map<String, String> serializePublicKey(RSAPublicKey key) => {
        'n': base64Encode(CryptoUtils.bigIntToBytes(key.modulus!)),
        'e': base64Encode(CryptoUtils.bigIntToBytes(key.exponent!)),
      };

  /// Deserialize a public key from a Firestore map.
  static RSAPublicKey deserializePublicKey(Map<String, dynamic> map) {
    final n = CryptoUtils.bytesToBigInt(base64Decode(map['n'] as String));
    final e = CryptoUtils.bytesToBigInt(base64Decode(map['e'] as String));
    return RSAPublicKey(n, e);
  }

  /// Serialize a key pair to a JSON string for [flutter_secure_storage].
  ///
  /// Stores `n`, `e`, `d`, `p`, `q` so both keys can be reconstructed.
  static String serializeKeyPair(RsaKeyPair pair) => jsonEncode({
        'n': base64Encode(CryptoUtils.bigIntToBytes(pair.publicKey.modulus!)),
        'e': base64Encode(CryptoUtils.bigIntToBytes(pair.publicKey.exponent!)),
        'd': base64Encode(
            CryptoUtils.bigIntToBytes(pair.privateKey.privateExponent!)),
        'p': base64Encode(CryptoUtils.bigIntToBytes(pair.privateKey.p!)),
        'q': base64Encode(CryptoUtils.bigIntToBytes(pair.privateKey.q!)),
      });

  /// Reconstruct a private key from the stored JSON.
  static RSAPrivateKey deserializePrivateKey(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return RSAPrivateKey(
      CryptoUtils.bytesToBigInt(base64Decode(m['n'] as String)),
      CryptoUtils.bytesToBigInt(base64Decode(m['d'] as String)),
      CryptoUtils.bytesToBigInt(base64Decode(m['p'] as String)),
      CryptoUtils.bytesToBigInt(base64Decode(m['q'] as String)),
    );
  }

  /// Reconstruct a public key from the stored JSON (same format as private key).
  static RSAPublicKey deserializePublicKeyFromKeyPairJson(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return RSAPublicKey(
      CryptoUtils.bytesToBigInt(base64Decode(m['n'] as String)),
      CryptoUtils.bytesToBigInt(base64Decode(m['e'] as String)),
    );
  }

  /// Extract the Firestore public key map from the stored key-pair JSON.
  /// Used to re-upload a public key without re-generating the private key.
  static Map<String, String> extractPublicKeyMap(String keyPairJson) {
    final m = jsonDecode(keyPairJson) as Map<String, dynamic>;
    return {
      'n': m['n'] as String,
      'e': m['e'] as String,
    };
  }
}

// ── Isolate entry point ──────────────────────────────────────────────────────
// Must be a top-level function — closures and instance methods cannot be
// passed to [compute].

RsaKeyPair _generateInIsolate(Uint8List seeds) {
  final rng = FortunaRandom()..seed(KeyParameter(seeds));
  final gen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), RsaService._keyBits, 64),
      rng,
    ));
  final pair = gen.generateKeyPair();
  return RsaKeyPair(
    publicKey: pair.publicKey as RSAPublicKey,
    privateKey: pair.privateKey as RSAPrivateKey,
  );
}
