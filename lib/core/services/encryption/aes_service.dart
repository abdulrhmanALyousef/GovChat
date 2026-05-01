import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'crypto_utils.dart';

/// Payload returned by [AesService.encrypt] and consumed by [AesService.decrypt].
class AesEncryptedData {
  /// Base-64-encoded AES-256-GCM ciphertext (includes 16-byte auth tag).
  final String ciphertext;

  /// Base-64-encoded 12-byte random nonce (IV).
  final String iv;

  const AesEncryptedData({required this.ciphertext, required this.iv});

  Map<String, String> toMap() => {'ciphertext': ciphertext, 'iv': iv};

  factory AesEncryptedData.fromMap(Map<String, dynamic> map) =>
      AesEncryptedData(
        ciphertext: map['ciphertext'] as String,
        iv: map['iv'] as String,
      );
}

/// AES-256-GCM symmetric encryption / decryption.
///
/// - 256-bit key (32 bytes)
/// - 96-bit random nonce per encryption (12 bytes, GCM best-practice)
/// - 128-bit authentication tag appended automatically to ciphertext
class AesService {
  AesService._();

  static const int _keyBytes = 32; // 256 bits
  static const int _ivBytes = 12; // 96 bits — optimal for GCM
  static const int _tagBits = 128; // 16-byte auth tag

  // ── Key generation ──────────────────────────────────────────────────────────

  /// Generate a cryptographically random AES-256 key.
  static Uint8List generateKey() => CryptoUtils.randomBytes(_keyBytes);

  // ── Encryption ──────────────────────────────────────────────────────────────

  /// Encrypt [plaintext] with AES-256-GCM using [key].
  ///
  /// A fresh random IV is generated for every call.
  /// The [AesEncryptedData.ciphertext] already contains the GCM auth tag
  /// appended by pointycastle (last 16 bytes).
  static AesEncryptedData encrypt(String plaintext, Uint8List key) {
    assert(key.length == _keyBytes, 'Key must be 32 bytes');

    final iv = CryptoUtils.randomBytes(_ivBytes);
    final input = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // encrypt
        AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)),
      );

    final output = Uint8List(cipher.getOutputSize(input.length));
    var len = cipher.processBytes(input, 0, input.length, output, 0);
    len += cipher.doFinal(output, len);

    return AesEncryptedData(
      ciphertext: base64Encode(output.sublist(0, len)),
      iv: base64Encode(iv),
    );
  }

  // ── Decryption ──────────────────────────────────────────────────────────────

  /// Decrypt [data] with AES-256-GCM using [key].
  ///
  /// Throws [InvalidCipherTextException] if the auth tag does not match
  /// (tampered ciphertext or wrong key). Callers must handle this exception.
  static String decrypt(AesEncryptedData data, Uint8List key) {
    assert(key.length == _keyBytes, 'Key must be 32 bytes');

    final iv = base64Decode(data.iv);
    final ciphertext = base64Decode(data.ciphertext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // decrypt
        AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)),
      );

    final output = Uint8List(cipher.getOutputSize(ciphertext.length));
    var len = cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    len += cipher.doFinal(output, len);

    return utf8.decode(output.sublist(0, len));
  }
}
