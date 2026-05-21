import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Secure backup and restore of E2EE key material using:
///   - PBKDF2-HMAC-SHA256 (100 000 iterations) for password-based key derivation
///   - AES-256-GCM for encryption of the key payload
///
/// Firestore path: `users/{uid}/e2eeBackup/encryptedKey`
///
/// ## Backup format versions
///
/// **v1 (legacy):** Encrypted payload is a raw base64 string — the X25519
/// private key only.  Conversation keys are NOT included, so after restore
/// they must be re-derived (which often fails after reinstall).
///
/// **v2 (current):** Encrypted payload is a JSON manifest containing the
/// identity key AND all conversation AES keys, stored with their exact
/// secure-storage identifiers so restore puts them back where decrypt
/// expects to find them.
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

  // ── Backup (v2 — full manifest) ───────────────────────────────────────────

  /// Create a full E2EE backup containing the identity key AND all
  /// conversation AES keys.
  ///
  /// [manifest] is the pre-built [BackupManifest] from [E2eeManager].
  /// The manifest is JSON-encoded, encrypted with PBKDF2+AES-GCM, and
  /// uploaded to `users/{uid}/e2eeBackup/encryptedKey`.
  static Future<void> createBackup({
    required String uid,
    required BackupManifest manifest,
    required String password,
  }) async {
    final plaintext = jsonEncode(manifest.toJson());
    final salt = _randomSalt();
    final keyBytes = await _deriveKey(password, salt);
    final secretKey = SecretKeyData(keyBytes);

    final secretBox = await _aesGcm.encryptString(
      plaintext,
      secretKey: secretKey,
    );

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
      'version': 2,
      'conversationKeyCount': manifest.conversationKeys.length,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[E2EE Backup] Full backup created for $uid '
        '(${manifest.conversationKeys.length} conversation keys)');
  }

  /// Legacy backup method — backs up only the private key (v1 format).
  ///
  /// Kept for backward compatibility.  New code should use [createBackup].
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

  // ── Restore (auto-detects v1 / v2) ────────────────────────────────────────

  /// Download, decrypt, and parse the backup.
  ///
  /// Returns a [BackupManifest] regardless of backup version:
  ///   - v2: full manifest with identity key + conversation keys
  ///   - v1 (legacy): manifest with identity key only, empty conversation keys
  ///
  /// Throws [E2eeBackupWrongPasswordException] if the password is incorrect.
  /// Throws [E2eeBackupNotFoundException] if no backup document exists.
  static Future<BackupManifest> restoreFromBackup({
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

    String clearText;
    try {
      final secretKey = SecretKeyData(keyBytes);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final clearBytes =
          await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      clearText = utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw E2eeBackupWrongPasswordException();
    } catch (_) {
      throw E2eeBackupWrongPasswordException();
    }

    // Auto-detect format: try JSON (v2) first, fall back to raw string (v1).
    try {
      final json = jsonDecode(clearText);
      if (json is Map<String, dynamic> && json.containsKey('version')) {
        final manifest = BackupManifest.fromJson(json);
        debugPrint('[E2EE Backup] v2 manifest restored for $uid '
            '(${manifest.conversationKeys.length} conversation keys)');
        return manifest;
      }
    } catch (_) {
      // Not JSON — treat as v1 (raw private key string).
    }

    // v1 legacy: the decrypted text IS the private key base64.
    debugPrint('[E2EE Backup] v1 (legacy) backup restored for $uid');
    return BackupManifest(
      version: 1,
      userId: uid,
      identityPrivateKey: clearText,
      identityPublicKeyFingerprint: null,
      conversationKeys: {},
      createdAt: null,
    );
  }

  /// Legacy restore — returns just the private key string.
  ///
  /// Kept for backward compatibility with existing callers that expect
  /// only the private key.  New code should use [restoreFromBackup].
  static Future<String> restorePrivateKey({
    required String uid,
    required String password,
  }) async {
    final manifest = await restoreFromBackup(uid: uid, password: password);
    return manifest.identityPrivateKey;
  }
}

// ── Backup Manifest ──────────────────────────────────────────────────────────

/// Complete E2EE key backup payload.
///
/// Contains the identity private key and all conversation AES keys with
/// their exact secure-storage identifiers.
class BackupManifest {
  final int version;
  final String userId;
  final String identityPrivateKey;
  final String? identityPublicKeyFingerprint;

  /// Maps secure-storage key → base64-encoded AES key.
  ///
  /// Storage keys use the format `e2ee_conv_{base64url(path)}` (or legacy
  /// `e2ee_conv_{hashCode}` for old entries).  During restore, each entry
  /// is written back with the EXACT same storage key so that
  /// [E2eeKeyStore.getConversationKey] finds them without re-derivation.
  final Map<String, String> conversationKeys;

  final String? createdAt;

  BackupManifest({
    required this.version,
    required this.userId,
    required this.identityPrivateKey,
    required this.identityPublicKeyFingerprint,
    required this.conversationKeys,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'userId': userId,
        'identityPrivateKey': identityPrivateKey,
        'identityPublicKeyFingerprint': identityPublicKeyFingerprint,
        'conversationKeys': conversationKeys,
        'createdAt': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final convKeys = <String, String>{};
    final rawConv = json['conversationKeys'];
    if (rawConv is Map) {
      for (final entry in rawConv.entries) {
        convKeys[entry.key.toString()] = entry.value.toString();
      }
    }

    return BackupManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      userId: json['userId'] as String? ?? '',
      identityPrivateKey: json['identityPrivateKey'] as String,
      identityPublicKeyFingerprint:
          json['identityPublicKeyFingerprint'] as String?,
      conversationKeys: convKeys,
      createdAt: json['createdAt'] as String?,
    );
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
