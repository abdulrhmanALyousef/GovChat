import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key used to persist the conversation-key index in secure storage.
///
/// This index is a JSON-encoded list of all storage keys that hold conversation
/// AES keys.  It exists because [FlutterSecureStorage.readAll] is unreliable
/// on some platforms (iOS Keychain enumeration issues, Android
/// EncryptedSharedPreferences bugs).  The index guarantees that backup always
/// includes every conversation key.
const _kConvKeyIndex = 'e2ee_conv_key_index';

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

  /// Conversation keys are stored under `e2ee_conv_{base64url(path)}`.
  ///
  /// Uses base64url encoding of the path bytes for a collision-free,
  /// deterministic storage key.  Previous versions used `hashCode` which
  /// is not guaranteed to be collision-free.
  static String _convKeyId(String conversationPath) {
    final encoded = base64Url.encode(utf8.encode(conversationPath));
    return 'e2ee_conv_$encoded';
  }

  /// Legacy storage key format for migration.
  static String _legacyConvKeyId(String conversationPath) =>
      'e2ee_conv_${conversationPath.hashCode.toRadixString(16)}';

  // ── In-memory cache ────────────────────────────────────────────────────────

  static String? _cachedPublicKey;
  static String? _cachedPrivateKey;
  static final Map<String, Uint8List> _convKeyCache = {};

  /// Synchronous check of the in-memory conversation key cache.
  /// Returns the key immediately if it was previously loaded into memory
  /// (e.g., by the chat list preview decrypt), or null if not cached.
  /// Does NOT read from secure storage — use [getConversationKey] for that.
  static Uint8List? getConversationKeyCached(String conversationPath) {
    return _convKeyCache[conversationPath];
  }

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
    _knownConvStorageKeys.add(storageKey);
    await _storage.write(key: storageKey, value: base64Encode(key));
    await _persistIndex();
    debugPrint('[E2EE] conversation key saved for $storageKey');
  }

  /// Load a cached conversation AES-256 key.
  /// Returns null if no key is stored for this conversation.
  static Future<Uint8List?> getConversationKey(String conversationPath) async {
    final cached = _convKeyCache[conversationPath];
    if (cached != null) return cached;

    // Try new storage key first, then fall back to legacy hashCode-based key.
    final storageKey = _convKeyId(conversationPath);
    var stored = await _storage.read(key: storageKey);

    if (stored == null) {
      // Migration: check legacy hashCode-based key.
      final legacyKey = _legacyConvKeyId(conversationPath);
      stored = await _storage.read(key: legacyKey);
      if (stored != null) {
        // Migrate to new key format and delete legacy entry.
        await _storage.write(key: storageKey, value: stored);
        await _storage.delete(key: legacyKey);
        debugPrint('[E2EE] migrated conversation key from legacy format');
      }
    }

    if (stored == null) return null;

    final key = base64Decode(stored);
    _convKeyCache[conversationPath] = Uint8List.fromList(key);
    return _convKeyCache[conversationPath];
  }

  /// Remove a specific conversation key from cache and storage.
  static Future<void> removeConversationKey(String conversationPath) async {
    _convKeyCache.remove(conversationPath);
    await _storage.delete(key: _convKeyId(conversationPath));
  }

  // ── Enumeration (for backup) ────────────────────────────────────────────────

  /// Prefix used for all conversation key storage entries.
  static const convKeyPrefix = 'e2ee_conv_';

  /// Read ALL conversation key entries from secure storage.
  ///
  /// Returns a map of `{storageKey: base64-encoded AES key}`.
  /// Used by the backup service to include conversation keys in the manifest.
  ///
  /// Uses a two-pronged strategy to guarantee completeness:
  ///   1. Try [readAll] (fast path — works on most devices).
  ///   2. Fall back to the persistent index and read each key individually.
  /// The union of both results is returned.
  static Future<Map<String, String>> getAllConversationEntries() async {
    final result = <String, String>{};

    // Strategy 1: readAll (may miss keys on some platforms).
    try {
      final all = await _storage.readAll();
      for (final entry in all.entries) {
        if (entry.key.startsWith(convKeyPrefix)) {
          result[entry.key] = entry.value;
        }
      }
    } catch (e) {
      debugPrint('[E2EE] readAll failed: $e');
    }

    // Strategy 2: persistent index — read each key individually.
    final indexKeys = await _loadIndex();
    for (final storageKey in indexKeys) {
      if (result.containsKey(storageKey)) continue;
      try {
        final value = await _storage.read(key: storageKey);
        if (value != null) {
          result[storageKey] = value;
        }
      } catch (e) {
        debugPrint('[E2EE] index key read failed ($storageKey): $e');
      }
    }

    // Strategy 3: in-memory known keys (covers keys saved this session).
    for (final storageKey in _knownConvStorageKeys) {
      if (result.containsKey(storageKey)) continue;
      try {
        final value = await _storage.read(key: storageKey);
        if (value != null) {
          result[storageKey] = value;
        }
      } catch (e) {
        debugPrint('[E2EE] known key read failed ($storageKey): $e');
      }
    }

    debugPrint(
      '[E2EE] enumerated ${result.length} conversation key(s) from storage',
    );
    return result;
  }

  /// Restore conversation keys from a backup manifest.
  ///
  /// Writes each `{storageKey: base64Value}` pair directly to secure storage
  /// using the exact same key identifiers, then populates the in-memory cache
  /// for any entry whose storage key can be decoded back to a conversation path.
  static Future<int> restoreConversationKeys(
    Map<String, String> entries,
  ) async {
    int restored = 0;
    for (final entry in entries.entries) {
      try {
        await _storage.write(key: entry.key, value: entry.value);
        _knownConvStorageKeys.add(entry.key);

        // Try to populate in-memory cache by reverse-decoding the storage key.
        // New-format keys: e2ee_conv_{base64url(path)} → decodable.
        // Legacy hashCode keys: not decodable → skip cache, will be loaded
        // lazily and migrated on first access.
        if (entry.key.startsWith(convKeyPrefix)) {
          final encoded = entry.key.substring(convKeyPrefix.length);
          try {
            final path = utf8.decode(base64Url.decode(encoded));
            _convKeyCache[path] = Uint8List.fromList(base64Decode(entry.value));
          } catch (_) {
            // Legacy hashCode key — can't reverse. Will be loaded on access.
          }
        }
        restored++;
      } catch (e) {
        debugPrint('[E2EE] failed to restore key ${entry.key}: $e');
      }
    }

    // Persist the index so future backups include these keys even if
    // readAll() is unreliable.
    await _persistIndex();

    debugPrint('[E2EE] restored $restored conversation key(s) from backup');
    return restored;
  }

  /// Verify that restored conversation keys are readable from storage.
  ///
  /// Returns the count of keys that could be read back successfully.
  /// Call after [restoreConversationKeys] to detect silent write failures.
  static Future<int> verifyRestoredKeys() async {
    int verified = 0;
    for (final storageKey in _knownConvStorageKeys) {
      try {
        final value = await _storage.read(key: storageKey);
        if (value != null) verified++;
      } catch (_) {}
    }
    debugPrint(
      '[E2EE] verified $verified/${_knownConvStorageKeys.length} '
      'conversation key(s) readable from storage',
    );
    return verified;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Track all conversation key storage-keys so we can purge them.
  static final Set<String> _knownConvStorageKeys = {};

  /// Clear all in-memory caches (call on logout).
  static void clearCache() {
    _cachedPublicKey = null;
    _cachedPrivateKey = null;
    _convKeyCache.clear();
    debugPrint('[E2EE] Key caches cleared');
  }

  /// Purge ALL conversation AES keys from both memory and secure storage.
  ///
  /// Must be called after identity key changes (restore, fresh generation)
  /// so that conversation keys derived with the OLD identity key are not
  /// loaded from storage and used for decryption.
  static Future<void> clearConversationKeys() async {
    // Also include keys from persistent index for thorough cleanup.
    final indexKeys = await _loadIndex();
    final allKeys = {..._knownConvStorageKeys, ...indexKeys};

    // 1. Delete all conversation keys from secure storage.
    for (final storageKey in allKeys) {
      try {
        await _storage.delete(key: storageKey);
      } catch (_) {}
    }
    _knownConvStorageKeys.clear();

    // 2. Clear persistent index.
    try {
      await _storage.delete(key: _kConvKeyIndex);
    } catch (_) {}

    // 3. Clear in-memory conversation cache (identity keys stay).
    _convKeyCache.clear();

    debugPrint('[E2EE] All conversation keys purged from memory + storage');
  }

  // ── Persistent Index ──────────────────────────────────────────────────────

  /// Persist the current set of known conversation key identifiers to storage.
  ///
  /// This index is read by [getAllConversationEntries] as a fallback when
  /// [readAll] doesn't return all entries.
  static Future<void> _persistIndex() async {
    try {
      final indexList = _knownConvStorageKeys.toList();
      await _storage.write(key: _kConvKeyIndex, value: jsonEncode(indexList));
    } catch (e) {
      debugPrint('[E2EE] failed to persist conv key index: $e');
    }
  }

  /// Load the persistent conversation key index from storage.
  static Future<Set<String>> _loadIndex() async {
    try {
      final raw = await _storage.read(key: _kConvKeyIndex);
      if (raw == null) return {};
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (e) {
      debugPrint('[E2EE] failed to load conv key index: $e');
      return {};
    }
  }

  /// Bootstrap the in-memory [_knownConvStorageKeys] from the persistent index.
  ///
  /// Call once at app startup (before backup or key operations) to ensure
  /// the in-memory set is populated even if the app was killed and restarted.
  static Future<void> loadIndexIntoMemory() async {
    final index = await _loadIndex();
    _knownConvStorageKeys.addAll(index);
    if (index.isNotEmpty) {
      debugPrint('[E2EE] loaded ${index.length} key(s) from persistent index');
    }
  }

  /// Delete all E2EE keys from secure storage and cache (full reset).
  static Future<void> deleteAll() async {
    clearCache();
    await clearConversationKeys();
    await _storage.delete(key: _kPublicKey);
    await _storage.delete(key: _kPrivateKey);
    debugPrint('[E2EE] All E2EE keys deleted from secure storage');
  }
}
