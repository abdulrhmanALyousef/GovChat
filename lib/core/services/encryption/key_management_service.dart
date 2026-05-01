import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

import 'rsa_service.dart';

/// Manages the per-user RSA key pair lifecycle:
///   • Generates on first login
///   • Stores the private key in [FlutterSecureStorage]
///   • Stores the public key in Firestore at `users/{uid}`
///   • Exposes [ensureInitialized] so that code running concurrently with
///     first-login key generation can safely wait for it to finish.
class KeyManagementService {
  KeyManagementService._();

  // ── Storage keys ─────────────────────────────────────────────────────────────
  static const _kKeyPair = 'e2ee_key_pair';
  static const _kKeyVersion = 'e2ee_key_version';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final _firestore = FirebaseFirestore.instance;

  // ── Init tracking ─────────────────────────────────────────────────────────────
  // Tracks the in-progress [initializeUserKeys] call so other code can await it.
  static Completer<void>? _initCompleter;

  /// Wait for [initializeUserKeys] to complete.
  ///
  /// Returns immediately if initialization was never started or has already
  /// finished.  Swallows errors — callers should fall back gracefully when
  /// [getPrivateKey] subsequently returns null.
  static Future<void> ensureInitialized() async {
    if (_initCompleter == null) return;
    try {
      await _initCompleter!.future;
    } catch (_) {
      // Error already logged inside initializeUserKeys; callers handle null key.
    }
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Call once after a successful sign-in.
  ///
  /// • If the device already has a key pair, ensures the public key is present
  ///   in Firestore (recovery after a reinstall / Firestore wipe).
  /// • If no key pair exists on device, generates one and uploads the public key.
  ///
  /// Sets the internal [_initCompleter] so that [ensureInitialized] can block
  /// until this finishes — important for chats opened immediately after login.
  static Future<void> initializeUserKeys(String uid) async {
    // Create a fresh completer for this session.
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      final stored = await _secureStorage.read(key: _kKeyPair);

      if (stored != null) {
        await _ensurePublicKeyInFirestore(uid, stored);
        completer.complete();
        return;
      }

      debugPrint('[E2EE] Generating RSA-2048 key pair for $uid …');
      final pair = await RsaService.generateKeyPair();
      final serialized = RsaService.serializeKeyPair(pair);

      await _secureStorage.write(key: _kKeyPair, value: serialized);
      await _secureStorage.write(key: _kKeyVersion, value: '1');

      await _uploadPublicKey(uid, serialized, version: 1);
      debugPrint('[E2EE] Key pair initialised for $uid');
      completer.complete();
    } catch (e) {
      debugPrint('[E2EE] initializeUserKeys error: $e');
      completer.completeError(e);
    }
  }

  // ── Accessors ─────────────────────────────────────────────────────────────────

  /// Return the current user's private key, or null if none is stored yet.
  static Future<RSAPrivateKey?> getPrivateKey() async {
    final json = await _secureStorage.read(key: _kKeyPair);
    if (json == null) return null;
    return RsaService.deserializePrivateKey(json);
  }

  /// Fetch another user's public key from Firestore.
  /// Returns null if the user has not registered a key yet.
  static Future<RSAPublicKey?> getPublicKey(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final raw = snap.data()?['publicKey'] as Map<String, dynamic>?;
      if (raw == null) return null;
      return RsaService.deserializePublicKey(raw);
    } catch (e) {
      debugPrint('[E2EE] getPublicKey($uid) error: $e');
      return null;
    }
  }

  // ── Key rotation ──────────────────────────────────────────────────────────────

  /// Generate a new key pair and replace both the local and Firestore copies.
  ///
  /// ⚠️  After rotation, all existing conversation keys (encrypted with the
  ///     old public key) are inaccessible.  Callers should clear the
  ///     conversation-key cache and re-distribute new conversation keys.
  static Future<void> rotateKeys(String uid) async {
    debugPrint('[E2EE] Rotating keys for $uid …');
    final pair = await RsaService.generateKeyPair();
    final serialized = RsaService.serializeKeyPair(pair);

    final current = int.tryParse(
          await _secureStorage.read(key: _kKeyVersion) ?? '1',
        ) ??
        1;
    final newVersion = current + 1;

    await _secureStorage.write(key: _kKeyPair, value: serialized);
    await _secureStorage.write(key: _kKeyVersion, value: '$newVersion');

    await _uploadPublicKey(uid, serialized, version: newVersion);
    debugPrint('[E2EE] Key rotation complete (v$newVersion)');
  }

  /// Handle a device change (reinstall, new device).
  static Future<void> handleDeviceChange(String uid) async {
    await _secureStorage.delete(key: _kKeyPair);
    await _secureStorage.delete(key: _kKeyVersion);
    await initializeUserKeys(uid);
  }

  // ── Convenience ───────────────────────────────────────────────────────────────

  /// Firebase UID of the currently authenticated user.
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Private helpers ───────────────────────────────────────────────────────────

  static Future<void> _ensurePublicKeyInFirestore(
    String uid,
    String keyPairJson,
  ) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    if (snap.data()?['publicKey'] != null) return;

    final publicKeyMap = RsaService.extractPublicKeyMap(keyPairJson);
    await _firestore.collection('users').doc(uid).set(
      {
        'publicKey': publicKeyMap,
        'keyVersion': 1,
        'keyUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    debugPrint('[E2EE] Restored public key to Firestore for $uid');
  }

  static Future<void> _uploadPublicKey(
    String uid,
    String keyPairJson, {
    required int version,
  }) async {
    final publicKeyMap = RsaService.extractPublicKeyMap(keyPairJson);
    await _firestore.collection('users').doc(uid).set(
      {
        'publicKey': publicKeyMap,
        'keyVersion': version,
        'keyUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
