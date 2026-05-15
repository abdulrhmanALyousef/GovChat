import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure local key storage for E2EE.
///
/// Stores:
///   - The user's X25519 key pair (identity keys)
///   - Derived conversation AES-256 keys (cached to avoid re-deriving)
///
/// All data is persisted in [FlutterSecureStorage] (Keychain on iOS/macOS,
/// EncryptedSharedPreferences on Android).
class E2eeKeyStore {
  E2eeKeyStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Storage key constants ──────────────────────────────────────────────────

  static const _kPublicKey = 'e2ee_x25519_public';
  static const _kPrivateKey = 'e2ee_x25519_private';

  /// Conversation keys are stored under `e2ee_conv_{sha256(path)}`.
  static String _convKeyId(String conversationPath) =>
      'e2ee_conv_${conversationPath.hashCode.toRadixString(16)}';

  // ── In-memory cache ────────────────────────────────────────────────────────

  static String? _cachedPublicKey;
  static String? _cachedPrivateKey;
  static final Map<String, Uint8List> _convKeyCache = {};

  // ── X25519 Key Pair ────────────────────────────────────────────────────────

  /// Save the user's X25519 key pair to secure storage.
  static Future<void> saveKeyPair({
    required String publicKey,
    required String privateKey,
  }) async {
    await Future.wait([
      _storage.write(key: _kPublicKey, value: publicKey),
      _storage.write(key: _kPrivateKey, value: privateKey),
    ]);
    _cachedPublicKey = publicKey;
    _cachedPrivateKey = privateKey;
    debugPrint('[E2EE] X25519 key pair saved to secure storage');
  }

  /// Load the user's X25519 public key (base64).
  static Future<String?> getPublicKey() async {
    if (_cachedPublicKey != null) return _cachedPublicKey;
    _cachedPublicKey = await _storage.read(key: _kPublicKey);
    return _cachedPublicKey;
  }

  /// Load the user's X25519 private key (base64).
  static Future<String?> getPrivateKey() async {
    if (_cachedPrivateKey != null) return _cachedPrivateKey;
    _cachedPrivateKey = await _storage.read(key: _kPrivateKey);
    return _cachedPrivateKey;
  }

  /// True if a key pair has been generated and stored.
  static Future<bool> hasKeyPair() async {
    return (await getPrivateKey()) != null;
  }

  // ── Conversation AES Keys ─────────────────────────────────────────────────

  /// Save a derived/received conversation AES-256 key.
  static Future<void> saveConversationKey(
    String conversationPath,
    Uint8List key,
  ) async {
    _convKeyCache[conversationPath] = key;
    final storageKey = _convKeyId(conversationPath);
    await _storage.write(key: storageKey, value: base64Encode(key));

    // ── DIAG ───────────────────────────────────────────────────────────────
    debugPrint('[E2EE-DIAG] saveConversationKey()');
    debugPrint('[E2EE-DIAG]   path       : $conversationPath');
    debugPrint('[E2EE-DIAG]   storageKey : $storageKey');
    debugPrint('[E2EE-DIAG]   AES KEY    : ${base64Encode(key)}');
    // ──────────────────────────────────────────────────────────────────────
  }

  /// Load a cached conversation AES-256 key.
  /// Returns null if no key is stored for this conversation.
  static Future<Uint8List?> getConversationKey(String conversationPath) async {
    final storageKey = _convKeyId(conversationPath);

    // ── DIAG ───────────────────────────────────────────────────────────────
    debugPrint('[E2EE-DIAG] getConversationKey() lookup');
    debugPrint('[E2EE-DIAG]   path       : $conversationPath');
    debugPrint('[E2EE-DIAG]   storageKey : $storageKey');
    // ──────────────────────────────────────────────────────────────────────

    final cached = _convKeyCache[conversationPath];
    if (cached != null) {
      debugPrint('[E2EE-DIAG]   result     : MEMORY CACHE HIT');
      debugPrint('[E2EE-DIAG]   AES KEY    : ${base64Encode(cached)}');
      return cached;
    }

    final stored = await _storage.read(key: storageKey);
    if (stored == null) {
      debugPrint('[E2EE-DIAG]   result     : MISS (not in memory or storage)');
      return null;
    }

    final key = base64Decode(stored);
    _convKeyCache[conversationPath] = Uint8List.fromList(key);
    debugPrint('[E2EE-DIAG]   result     : SECURE STORAGE HIT');
    debugPrint('[E2EE-DIAG]   AES KEY    : $stored');
    return _convKeyCache[conversationPath];
  }

  /// Remove a specific conversation key from cache and storage.
  static Future<void> removeConversationKey(String conversationPath) async {
    _convKeyCache.remove(conversationPath);
    await _storage.delete(key: _convKeyId(conversationPath));
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Clear all in-memory caches (call on logout).
  static void clearCache() {
    _cachedPublicKey = null;
    _cachedPrivateKey = null;
    _convKeyCache.clear();
    debugPrint('[E2EE] Key caches cleared');
  }

  /// Delete all E2EE keys from secure storage and cache (full reset).
  static Future<void> deleteAll() async {
    clearCache();
    await _storage.delete(key: _kPublicKey);
    await _storage.delete(key: _kPrivateKey);
    // Note: conversation keys in storage use dynamic names.
    // A full deleteAll() on the storage would also work but may affect
    // non-E2EE data.  The conversation keys will be re-derived on next use.
    debugPrint('[E2EE] All E2EE keys deleted from secure storage');
  }
}
