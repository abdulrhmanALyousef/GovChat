import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Low-level cryptographic operations using the `cryptography` package.
///
/// - X25519 for key agreement (private/group key exchange)
/// - HKDF-SHA256 for key derivation
/// - AES-256-GCM for message encryption/decryption
class E2eeCrypto {
  E2eeCrypto._();

  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ── X25519 Key Pair ────────────────────────────────────────────────────────

  /// Generate a new X25519 key pair.
  /// Returns `{publicKey, privateKey}` as base64 strings.
  static Future<E2eeKeyPair> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return E2eeKeyPair(
      publicKey: base64Encode(publicKey.bytes),
      privateKey: base64Encode(privateBytes),
    );
  }

  // ── Shared Secret (X25519 + HKDF) ─────────────────────────────────────────

  /// Derive a 32-byte AES-256 key from an X25519 shared secret.
  ///
  /// [myPrivateKeyB64]    — local user's X25519 private key (base64)
  /// [theirPublicKeyB64]  — remote user's X25519 public key (base64)
  /// [info]               — HKDF context string (e.g. conversation path)
  static Future<Uint8List> deriveSharedKey({
    required String myPrivateKeyB64,
    required String theirPublicKeyB64,
    required String info,
  }) async {
    final myPrivateBytes = base64Decode(myPrivateKeyB64);
    final theirPublicBytes = base64Decode(theirPublicKeyB64);

    final myKeyPair = await _x25519.newKeyPairFromSeed(myPrivateBytes);
    final theirPublicKey = SimplePublicKey(
      theirPublicBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );

    final derived = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: Uint8List(0),
      info: utf8.encode(info),
    );

    return Uint8List.fromList(await derived.extractBytes());
  }

  // ── Public Key Re-derivation ───────────────────────────────────────────────

  /// Re-derive the X25519 public key from a stored private key seed (base64).
  ///
  /// Used when restoring a backed-up private key to reconstruct the full pair.
  static Future<String> derivePublicKeyFromPrivate(
    String privateKeyB64,
  ) async {
    final privateBytes = base64Decode(privateKeyB64);
    final keyPair = await _x25519.newKeyPairFromSeed(privateBytes);
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  // ── AES-256-GCM Key Generation ─────────────────────────────────────────────

  /// Generate a random 32-byte AES-256 key for group chats.
  static Future<Uint8List> generateGroupKey() async {
    final secretKey = await _aesGcm.newSecretKey();
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  // ── AES-256-GCM Encrypt ────────────────────────────────────────────────────

  /// Encrypt [plaintext] with AES-256-GCM using [keyBytes].
  ///
  /// Returns an [EncryptedPayload] with base64-encoded ciphertext and nonce.
  static Future<EncryptedPayload> encrypt(
    String plaintext,
    Uint8List keyBytes,
  ) async {
    final secretKey = SecretKeyData(keyBytes);
    final secretBox = await _aesGcm.encryptString(
      plaintext,
      secretKey: secretKey,
    );
    // Concatenate ciphertext + MAC (standard GCM format).
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return EncryptedPayload(
      ciphertext: base64Encode(combined),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  /// Encrypt raw bytes with AES-256-GCM.
  static Future<EncryptedPayload> encryptBytes(
    Uint8List data,
    Uint8List keyBytes,
  ) async {
    final secretKey = SecretKeyData(keyBytes);
    final secretBox = await _aesGcm.encrypt(
      data,
      secretKey: secretKey,
    );
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return EncryptedPayload(
      ciphertext: base64Encode(combined),
      nonce: base64Encode(secretBox.nonce),
    );
  }

  // ── AES-256-GCM Decrypt ────────────────────────────────────────────────────

  /// Decrypt an [EncryptedPayload] with AES-256-GCM using [keyBytes].
  ///
  /// Throws [SecretBoxAuthenticationError] if the key is wrong or data is
  /// corrupted (equivalent to the old InvalidCipherTextException).
  static Future<String> decrypt(
    EncryptedPayload payload,
    Uint8List keyBytes,
  ) async {
    final combined = base64Decode(payload.ciphertext);
    final nonce = base64Decode(payload.nonce);

    // Last 16 bytes = GCM MAC tag.
    final macLength = 16;
    final cipherText = combined.sublist(0, combined.length - macLength);
    final mac = Mac(combined.sublist(combined.length - macLength));

    final secretKey = SecretKeyData(keyBytes);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    final clearText = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(clearText);
  }

  /// Decrypt raw bytes with AES-256-GCM.
  static Future<Uint8List> decryptBytes(
    EncryptedPayload payload,
    Uint8List keyBytes,
  ) async {
    final combined = base64Decode(payload.ciphertext);
    final nonce = base64Decode(payload.nonce);

    final macLength = 16;
    final cipherText = combined.sublist(0, combined.length - macLength);
    final mac = Mac(combined.sublist(combined.length - macLength));

    final secretKey = SecretKeyData(keyBytes);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    final clearText = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(clearText);
  }

  // ── Group Key Wrapping ─────────────────────────────────────────────────────

  /// Encrypt a group AES key with an X25519-derived shared key so it can be
  /// stored in Firestore for a specific member.
  static Future<EncryptedPayload> wrapGroupKey({
    required Uint8List groupKey,
    required String senderPrivateKeyB64,
    required String recipientPublicKeyB64,
    required String info,
  }) async {
    final sharedKey = await deriveSharedKey(
      myPrivateKeyB64: senderPrivateKeyB64,
      theirPublicKeyB64: recipientPublicKeyB64,
      info: info,
    );
    return encryptBytes(groupKey, sharedKey);
  }

  /// Decrypt a group AES key that was wrapped with [wrapGroupKey].
  static Future<Uint8List> unwrapGroupKey({
    required EncryptedPayload wrappedKey,
    required String myPrivateKeyB64,
    required String senderPublicKeyB64,
    required String info,
  }) async {
    final sharedKey = await deriveSharedKey(
      myPrivateKeyB64: myPrivateKeyB64,
      theirPublicKeyB64: senderPublicKeyB64,
      info: info,
    );
    return decryptBytes(wrappedKey, sharedKey);
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

/// A base64-encoded X25519 key pair.
class E2eeKeyPair {
  final String publicKey;
  final String privateKey;

  const E2eeKeyPair({required this.publicKey, required this.privateKey});
}

/// Base64-encoded AES-256-GCM ciphertext + nonce.
/// Wire-compatible with the old [AesEncryptedData] format used in Firestore.
class EncryptedPayload {
  final String ciphertext;
  final String nonce;

  const EncryptedPayload({required this.ciphertext, required this.nonce});
}
