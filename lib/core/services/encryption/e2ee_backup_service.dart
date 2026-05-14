import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Secure backup and restore of the X25519 private key using:
///   - PBKDF2-HMAC-SHA256 (100 000 iterations) for password-based key derivation
///   - AES-256-GCM for encryption of the private key bytes
///
/// Firestore path: `users/{uid}/e2eeBackup/encryptedKey`
/// Fields stored: `ciphertext` (base64), `nonce` (base64), `salt` (base64),
///                `iterations` (int), `createdAt` (Timestamp)
class E2eeBackupService {
  E2eeBackupService._();

  static const int _iterations = 100000;
  static const String _backupCollection = 'e2eeBackup';
  static const String _backupDocId = 'encryptedKey';

  static final _aesGcm = AesGcm.with256bits();
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  // ── Key Derivation ─────────────────────────────────────────────────────────

  static Future<Uint8List> _deriveKey(
    String password,
    List<int> salt,
  ) async {
    final derived = await _pbkdf2.deriveKey(
      secretKey: SecretKeyData(utf8.encode(password)),
      nonce: salt,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  static List<int> _randomSalt() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256));
  }

  // ── Backup ─────────────────────────────────────────────────────────────────

  /// Encrypt [privateKeyB64] with a PBKDF2-derived key from [password] and
  /// upload the result to `users/{uid}/e2eeBackup/encryptedKey`.
  static Future<void> backupPrivateKey({
    required String uid,
    required String privateKeyB64,
    required String password,
  }) async {
    final salt = _randomSalt();
    final keyBytes = await _deriveKey(password, salt);
    final secretKey = SecretKeyData(keyBytes);

    final secretBox = await _aesGcm.encryptString(
      privateKeyB64,
      secretKey: secretKey,
    );

    // Concatenate ciphertext + GCM authentication tag (same layout as E2eeCrypto).
    final combined = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_backupCollection)
        .doc(_backupDocId)
        .set({
      'ciphertext': base64Encode(combined),
      'nonce': base64Encode(Uint8List.fromList(secretBox.nonce)),
      'salt': base64Encode(Uint8List.fromList(salt)),
      'iterations': _iterations,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[E2EE Backup] Private key backed up for $uid');
  }

  // ── Check ──────────────────────────────────────────────────────────────────

  /// Returns `true` if a backup document exists in Firestore for [uid].
  static Future<bool> hasBackup(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(_backupCollection)
          .doc(_backupDocId)
          .get();
      return snap.exists;
    } catch (e) {
      debugPrint('[E2EE Backup] hasBackup error: $e');
      return false;
    }
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  /// Download and decrypt the backed-up private key from Firestore.
  ///
  /// Throws [E2eeBackupWrongPasswordException] if the password is incorrect.
  /// Throws [E2eeBackupNotFoundException] if no backup document exists.
  static Future<String> restorePrivateKey({
    required String uid,
    required String password,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_backupCollection)
        .doc(_backupDocId)
        .get();

    if (!snap.exists) throw E2eeBackupNotFoundException();

    final data = snap.data()!;
    final combined = base64Decode(data['ciphertext'] as String);
    final nonce = base64Decode(data['nonce'] as String);
    final salt = base64Decode(data['salt'] as String);

    final keyBytes = await _deriveKey(password, salt);

    const macLength = 16;
    final cipherText = combined.sublist(0, combined.length - macLength);
    final mac = Mac(combined.sublist(combined.length - macLength));

    try {
      final secretKey = SecretKeyData(keyBytes);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      debugPrint('[E2EE Backup] Private key restored for $uid');
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw E2eeBackupWrongPasswordException();
    } catch (_) {
      throw E2eeBackupWrongPasswordException();
    }
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

class E2eeBackupNotFoundException implements Exception {
  @override
  String toString() => 'E2EE backup not found.';
}

class E2eeBackupWrongPasswordException implements Exception {
  @override
  String toString() => 'Wrong backup password.';
}
