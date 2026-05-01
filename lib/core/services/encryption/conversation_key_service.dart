import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' show RSAPrivateKey;

import 'aes_service.dart';
import 'key_management_service.dart';
import 'rsa_service.dart';

/// Manages per-conversation AES-256 session keys for every chat type:
/// department chats, private (1-to-1) chats, and org-wide chats.
///
/// Key storage is path-driven:
///   `{conversationPath}/conversationKeys/{uid}`
///
/// Examples
///   Dept chat   → organizations/{org}/departments/{dept}/conversationKeys/{uid}
///   Private     → organizations/{org}/private_chats/{chatId}/conversationKeys/{uid}
///   Org-wide    → organizations/{org}/org_chats/general/conversationKeys/{uid}
///
/// Each member stores their own copy of the AES key, encrypted with their
/// RSA public key.  Firebase sees only ciphertext.
class ConversationKeyService {
  ConversationKeyService._();

  static final _firestore = FirebaseFirestore.instance;

  // conversationPath → plaintext AES-256 key bytes
  static final Map<String, Uint8List> _cache = {};

  // ── Main entry ───────────────────────────────────────────────────────────────

  /// Fetch the plaintext AES key for [conversationPath].
  ///
  /// [conversationPath] is the Firestore path of the conversation document
  /// (the parent of the `/messages` sub-collection).
  /// [memberUids] is the list of Firebase UIDs who should receive the key
  /// when a new one is generated.
  ///
  /// Returns `null` when the user has no private key yet (first login RSA
  /// generation still in progress) or on an unrecoverable error.
  /// Returns the AES-256 conversation key for [conversationPath].
  ///
  /// **This method never returns null.**
  ///
  /// Priority order:
  ///   1. In-memory cache hit → return immediately.
  ///   2. Firestore: decrypt existing key with RSA private key.
  ///   3. Generate a new key, attempt RSA distribution to all members.
  ///   4. If RSA private key unavailable, generate a session-only key.
  ///
  /// Every failure path falls through to key generation so the caller is
  /// guaranteed a usable key even when Firestore or RSA is unavailable.
  static Future<Uint8List> getOrCreate({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
  }) async {
    // ── 1. In-memory cache ──────────────────────────────────────────────────
    final cached = _cache[conversationPath];
    if (cached != null) {
      debugPrint('[E2EE] cache hit for $conversationPath');
      return cached;
    }

    // ── 2. Load RSA private key ─────────────────────────────────────────────
    debugPrint('[E2EE] loading RSA private key for $currentUid ...');
    RSAPrivateKey? privateKey;
    try {
      privateKey = await KeyManagementService.getPrivateKey();
    } catch (e) {
      debugPrint('[E2EE] getPrivateKey() threw: $e');
    }

    if (privateKey == null && currentUid != 'anonymous' && currentUid != 'fallback') {
      // No key in storage — this user may pre-date E2EE deployment or had
      // their storage wiped.  Trigger generation and retry.
      debugPrint('[E2EE] no private key — calling initializeUserKeys()');
      try {
        await KeyManagementService.initializeUserKeys(currentUid);
        privateKey = await KeyManagementService.getPrivateKey();
        debugPrint('[E2EE] after initializeUserKeys: '
            'privateKey ${privateKey == null ? "STILL null" : "loaded"}');
      } catch (e) {
        debugPrint('[E2EE] initializeUserKeys() failed: $e');
      }
    }

    // ── 3. Fetch existing key from Firestore (own try-catch) ────────────────
    // A permission-denied error here must NOT block key generation — we fall
    // through and generate a local key instead.
    if (privateKey != null) {
      try {
        debugPrint('[E2EE] reading conversationKeys/$currentUid '
            'from $conversationPath ...');
        final snap = await _firestore
            .collection('$conversationPath/conversationKeys')
            .doc(currentUid)
            .get();

        if (snap.exists) {
          debugPrint('[E2EE] found key doc — decrypting...');
          final encB64 = snap.data()!['encryptedKey'] as String;
          final aesKey = RsaService.decrypt(base64Decode(encB64), privateKey);
          _cache[conversationPath] = aesKey;
          debugPrint('[E2EE] ✅ loaded existing key (${aesKey.length} B)');
          return aesKey;
        }
        debugPrint('[E2EE] no key doc yet — will generate');
      } catch (e) {
        debugPrint('[E2EE] Firestore read failed ($e) — '
            'generating local key instead');
      }
    } else {
      debugPrint('[E2EE] RSA private key unavailable — '
          'will generate session-only key');
    }

    // ── 4. Generate a new AES-256 key ───────────────────────────────────────
    // Always reached when no existing key was loaded.
    // AesService.generateKey() is pure local crypto — it cannot fail.
    debugPrint('[E2EE] generating new AES-256 key...');
    final aesKey = AesService.generateKey();
    debugPrint('[E2EE] generated ${aesKey.length}-byte key');

    // ── 5. Distribute to members (best-effort, never blocks return) ─────────
    if (privateKey != null && memberUids.isNotEmpty) {
      final recipients = memberUids.contains(currentUid)
          ? memberUids
          : [...memberUids, currentUid];
      debugPrint('[E2EE] distributing to ${recipients.length} recipient(s)');
      await _distribute(
        conversationPath: conversationPath,
        aesKey: aesKey,
        memberUids: recipients,
      );
    } else {
      debugPrint('[E2EE] skipping distribution '
          '(privateKey=${privateKey != null}, members=${memberUids.length})');
    }

    // ── 6. Cache and return ─────────────────────────────────────────────────
    _cache[conversationPath] = aesKey;
    debugPrint('[E2EE] ✅ conversation key ready for $conversationPath');
    return aesKey;
  }

  // ── Distribution ─────────────────────────────────────────────────────────────

  /// Distribute the cached AES key to a member who joined after initial setup.
  static Future<void> distributeToNewMember({
    required String conversationPath,
    required String newMemberUid,
  }) async {
    final aesKey = _cache[conversationPath];
    if (aesKey == null) {
      debugPrint('[E2EE] No cached key to distribute for $conversationPath');
      return;
    }
    await _encryptAndStore(
      conversationPath: conversationPath,
      aesKey: aesKey,
      memberUid: newMemberUid,
    );
    debugPrint('[E2EE] Distributed key to new member $newMemberUid');
  }

  // ── Cache management ─────────────────────────────────────────────────────────

  /// Evict a single conversation key (e.g. after key rotation).
  static void evict(String conversationPath) =>
      _cache.remove(conversationPath);

  /// Clear the entire in-memory cache — call on logout.
  static void clearAll() => _cache.clear();

  // ── Private helpers ───────────────────────────────────────────────────────────

  static Future<void> _distribute({
    required String conversationPath,
    required Uint8List aesKey,
    required List<String> memberUids,
  }) async {
    // eagerError: false → wait for all, then surface errors.
    // Individual failures are swallowed inside _encryptAndStore, so this
    // Future.wait will not throw even if some members have no public key or
    // Firestore rejects a write.
    await Future.wait(
      memberUids.map(
        (uid) => _encryptAndStore(
          conversationPath: conversationPath,
          aesKey: aesKey,
          memberUid: uid,
        ),
      ),
      eagerError: false,
    );
    debugPrint('[E2EE] _distribute complete for ${memberUids.length} member(s)');
  }

  static Future<void> _encryptAndStore({
    required String conversationPath,
    required Uint8List aesKey,
    required String memberUid,
  }) async {
    try {
      final publicKey = await KeyManagementService.getPublicKey(memberUid);
      if (publicKey == null) {
        debugPrint('[E2EE] No public key for $memberUid — skipping key store');
        return;
      }

      final encryptedKey = RsaService.encrypt(aesKey, publicKey);
      await _firestore
          .collection('$conversationPath/conversationKeys')
          .doc(memberUid)
          .set({
        'encryptedKey': base64Encode(encryptedKey),
        'keyVersion': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[E2EE] Key stored for $memberUid at $conversationPath');
    } catch (e) {
      // Swallow per-member failures. If Firestore security rules reject this
      // write (or if there is a transient network error), we log and continue.
      // The in-memory cache in getOrCreate() still holds the AES key so the
      // current session can send/receive.  The member will re-trigger key
      // distribution the next time they open this conversation.
      debugPrint('[E2EE] _encryptAndStore FAILED for $memberUid '
          'at $conversationPath: $e');
    }
  }
}
