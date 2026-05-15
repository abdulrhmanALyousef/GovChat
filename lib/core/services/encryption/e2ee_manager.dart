import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'e2ee_crypto.dart';
import 'e2ee_key_store.dart';

/// High-level E2EE manager that coordinates:
///
///   1. X25519 identity key generation and Firestore publication.
///   2. Private chat: X25519 key agreement → HKDF → AES-256-GCM key.
///   3. Group chat: random AES-256-GCM key wrapped per-member with X25519.
///   4. Message encrypt / decrypt helpers.
///
/// Firestore schema:
///   - `users/{uid}.e2eePublicKey`       — user's X25519 public key (base64)
///   - `employees/{uid}.e2eePublicKey`   — fallback location for same key
///   - `{conversationPath}/groupKey/{uid}` — per-member wrapped group key
///       fields: `wrappedKey`, `nonce`, `creatorUid`, `creatorPublicKey`
///   - `{conversationPath}/groupKey/_lock` — creation-lock sentinel doc
///       fields: `creatorUid`, `createdAt`
class E2eeManager {
  E2eeManager._();

  static final _firestore = FirebaseFirestore.instance;

  // ── Init tracking ──────────────────────────────────────────────────────────
  static Completer<void>? _initCompleter;

  /// Wait for [initializeKeys] to complete.  Safe to call multiple times.
  static Future<void> ensureInitialized() async {
    if (_initCompleter == null) return;
    try {
      await _initCompleter!.future;
    } catch (_) {}
  }

  /// Firebase UID of the currently authenticated user.
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Key Initialisation ─────────────────────────────────────────────────────

  /// Call once after sign-in.  Generates an X25519 key pair if none exists,
  /// then ensures the public key is published to Firestore.
  static Future<void> initializeKeys(String uid) async {
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      final hasKeys = await E2eeKeyStore.hasKeyPair();

      if (hasKeys) {
        debugPrint('[E2EE] X25519 key pair already exists in secure storage');
        final pubKey = await E2eeKeyStore.getPublicKey();
        if (pubKey != null) {
          await _ensurePublicKeyInFirestore(uid, pubKey);
        }
        completer.complete();
        return;
      }

      // No local key pair — generate a FRESH one.
      // This is the only path after reinstall (backup restore is disabled).
      debugPrint('[E2EE] No local key pair — generating FRESH X25519 keys for $uid ...');
      final keyPair = await E2eeCrypto.generateKeyPair();

      await E2eeKeyStore.saveKeyPair(
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
      );
      await _uploadPublicKey(uid, keyPair.publicKey);

      // Clear any stale conversation AES keys that were derived with old
      // identity keys.  They will be re-derived using the new key pair.
      E2eeKeyStore.clearCache();

      debugPrint('[E2EE] Fresh X25519 key pair generated and published for $uid');
      completer.complete();
    } catch (e) {
      debugPrint('[E2EE] initializeKeys error: $e');
      completer.completeError(e);
    }
  }

  // ── Conversation Key Retrieval ─────────────────────────────────────────────

  /// Get the AES-256 conversation key for [conversationPath].
  ///
  /// [forceRefresh] bypasses all local caches and forces server-side reads
  /// for public keys. Use after MAC errors to pick up regenerated identity keys.
  static Future<Uint8List?> getConversationKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required bool isPrivateChat,
    bool forceRefresh = false,
  }) async {
    debugPrint('[E2EE] getConversationKey  path=$conversationPath  '
        'private=$isPrivateChat  forceRefresh=$forceRefresh');

    // ── 1. Check local cache / storage ─────────────────────────────────────
    if (forceRefresh) {
      await E2eeKeyStore.removeConversationKey(conversationPath);
    } else {
      final cached = await E2eeKeyStore.getConversationKey(conversationPath);
      if (cached != null) {
        debugPrint('[E2EE] conversation key loaded from cache');
        return cached;
      }
    }

    // ── 2. Load own private key ────────────────────────────────────────────
    final myPrivateKey = await E2eeKeyStore.getPrivateKey();
    if (myPrivateKey == null) {
      debugPrint('[E2EE] no local private key — cannot derive conversation key');
      return null;
    }

    if (isPrivateChat) {
      return _derivePrivateChatKey(
        conversationPath: conversationPath,
        currentUid: currentUid,
        memberUids: memberUids,
        myPrivateKey: myPrivateKey,
        forceServer: forceRefresh,
      );
    } else {
      return _getOrCreateGroupKey(
        conversationPath: conversationPath,
        currentUid: currentUid,
        memberUids: memberUids,
        myPrivateKey: myPrivateKey,
        forceServer: forceRefresh,
      );
    }
  }

  // ── Private Chat: X25519 Key Agreement ─────────────────────────────────────

  /// Derives the AES key from X25519(myPrivateKey, theirPublicKey) + HKDF.
  ///
  /// When [forceServer] is true, the other user's public key is fetched
  /// directly from Firestore server — bypassing SDK cache. This ensures
  /// we pick up a regenerated identity key after reinstall or storage wipe.
  static Future<Uint8List?> _derivePrivateChatKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
    bool forceServer = false,
  }) async {
    final otherUid = memberUids.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => currentUid,
    );

    debugPrint('[E2EE] private chat: deriving key with $otherUid'
        '${forceServer ? ' (server fetch)' : ''}');

    final theirPublicKey = await _getPublicKey(
      otherUid,
      forceServer: forceServer,
    );
    if (theirPublicKey == null) {
      debugPrint('[E2EE] no public key for $otherUid');
      return null;
    }

    try {
      final aesKey = await E2eeCrypto.deriveSharedKey(
        myPrivateKeyB64: myPrivateKey,
        theirPublicKeyB64: theirPublicKey,
        info: 'govchat:private:$conversationPath',
      );

      await E2eeKeyStore.saveConversationKey(conversationPath, aesKey);
      debugPrint('[E2EE] private chat key derived (${aesKey.length} bytes)');
      return aesKey;
    } catch (e) {
      debugPrint('[E2EE] key derivation failed: $e');
      return null;
    }
  }

  // ── Group Chat: Shared AES Key ─────────────────────────────────────────────
  //
  // Uses a Firestore TRANSACTION on a `_lock` sentinel doc to guarantee
  // exactly ONE device generates the group AES key.
  //
  // Recovery path: when _unwrapAndSave() fails (identity key changed),
  // ALL groupKey docs + _lock are deleted so we regenerate from scratch
  // with everyone's CURRENT public keys.

  static Future<Uint8List?> _getOrCreateGroupKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
    bool forceServer = false,
  }) async {
    debugPrint('[E2EE] group chat: resolving key for $conversationPath');

    final groupKeyCol = _firestore.collection('$conversationPath/groupKey');
    final myDocRef = groupKeyCol.doc(currentUid);

    // ── Pre-scan: detect and auto-fix race-condition corruption ──────────
    try {
      final allKeyDocs = await groupKeyCol.get();
      final memberDocs = allKeyDocs.docs.where((d) => d.id != '_lock').toList();

      final creators = memberDocs
          .map((d) => d.data()['creatorUid'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();

      if (creators.length > 1) {
        debugPrint('[E2EE] race condition detected (${creators.length} creators) '
            '— deleting all groupKey docs');
        final batch = _firestore.batch();
        for (final doc in allKeyDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        // Fall through to creation path below.
      }
    } catch (e) {
      debugPrint('[E2EE] pre-scan error: $e');
    }

    // ── STEP 1: Try own Firestore doc (fast path) ─────────────────────────
    try {
      final myDoc = await myDocRef.get();
      if (myDoc.exists) {
        final key = await _unwrapAndSave(
          conversationPath: conversationPath,
          currentUid: currentUid,
          data: myDoc.data()!,
          myPrivateKey: myPrivateKey,
          memberUids: memberUids,
        );
        if (key != null) return key;

        // Unwrap failed — identity keys changed.
        // Delete ALL groupKey docs + _lock so we regenerate with fresh keys.
        debugPrint('[E2EE] unwrap failed — deleting stale groupKey docs');
        try {
          final staleDocs = await groupKeyCol.get();
          if (staleDocs.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in staleDocs.docs) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            debugPrint('[E2EE] deleted ${staleDocs.docs.length} stale docs');
          }
        } catch (cleanupErr) {
          debugPrint('[E2EE] cleanup error: $cleanupErr');
        }
        // Fall through to Step 2 — create fresh key.
      }
    } catch (e) {
      debugPrint('[E2EE] failed to read own group key doc: $e');
    }

    // ── STEP 2: Atomic lock — only ONE device generates the group key ─────
    final lockRef = _firestore.doc('$conversationPath/groupKey/_lock');
    final candidateKey = await E2eeCrypto.generateGroupKey();

    bool weWon = false;

    try {
      await _firestore.runTransaction((txn) async {
        final lockSnap = await txn.get(lockRef);
        if (!lockSnap.exists) {
          txn.set(lockRef, {
            'creatorUid': currentUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          weWon = true;
        } else {
          weWon = false;
        }
      });
    } catch (e) {
      debugPrint('[E2EE] lock transaction failed: $e');
    }

    // ── STEP 3a: We WON — distribute to all members ──────────────────────
    if (weWon) {
      debugPrint('[E2EE] won lock — creating and distributing group key');
      try {
        await _distributeGroupKey(
          conversationPath: conversationPath,
          groupKey: candidateKey,
          currentUid: currentUid,
          memberUids: memberUids,
          myPrivateKey: myPrivateKey,
          forceServer: true,
        );

        await E2eeKeyStore.saveConversationKey(conversationPath, candidateKey);
        debugPrint('[E2EE] group key created (${candidateKey.length} bytes)');
        return candidateKey;
      } catch (e) {
        debugPrint('[E2EE] group key creation failed: $e');
        return null;
      }
    }

    // ── STEP 3b: We LOST — wait for distribution ──────────────────────────
    debugPrint('[E2EE] lost lock — waiting for distribution');

    for (int attempt = 1; attempt <= 5; attempt++) {
      await Future.delayed(Duration(seconds: attempt));
      try {
        final retryDoc = await myDocRef.get();
        if (retryDoc.exists) {
          debugPrint('[E2EE] received key doc on attempt $attempt');
          return await _unwrapAndSave(
            conversationPath: conversationPath,
            currentUid: currentUid,
            data: retryDoc.data()!,
            myPrivateKey: myPrivateKey,
            memberUids: memberUids,
          );
        }
      } catch (e) {
        debugPrint('[E2EE] retry $attempt error: $e');
      }
    }

    debugPrint('[E2EE] group key not distributed — returning null');
    return null;
  }

  // ── Shared unwrap + save helper ────────────────────────────────────────────

  /// Unwrap a member's group key doc, save to local storage, and start
  /// background distribution to any members who don't have a copy yet.
  ///
  /// Returns null if the doc is malformed or the unwrap fails (indicating
  /// that the creator's or our own identity key has changed).
  static Future<Uint8List?> _unwrapAndSave({
    required String conversationPath,
    required String currentUid,
    required Map<String, dynamic> data,
    required String myPrivateKey,
    required List<String> memberUids,
  }) async {
    final wrappedKey = data['wrappedKey'] as String?;
    final nonce = data['nonce'] as String?;
    final creatorPublicKey = data['creatorPublicKey'] as String?;

    if (wrappedKey == null || nonce == null || creatorPublicKey == null) {
      debugPrint('[E2EE] groupKey doc missing required fields');
      return null;
    }

    try {
      final groupKey = await E2eeCrypto.unwrapGroupKey(
        wrappedKey: EncryptedPayload(ciphertext: wrappedKey, nonce: nonce),
        myPrivateKeyB64: myPrivateKey,
        senderPublicKeyB64: creatorPublicKey,
        info: 'govchat:group:$conversationPath',
      );

      await E2eeKeyStore.saveConversationKey(conversationPath, groupKey);
      debugPrint('[E2EE] group key unwrapped and saved (${groupKey.length} bytes)');

      // Background: ensure all current members have a copy.
      _distributeGroupKeyBackground(
        conversationPath: conversationPath,
        groupKey: groupKey,
        currentUid: currentUid,
        memberUids: memberUids,
        myPrivateKey: myPrivateKey,
      );

      return groupKey;
    } catch (e) {
      debugPrint('[E2EE] unwrap failed: $e — identity key likely changed');
      return null;
    }
  }

  // ── Group Key Distribution ─────────────────────────────────────────────────

  static Future<void> _distributeGroupKey({
    required String conversationPath,
    required Uint8List groupKey,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
    bool forceServer = false,
  }) async {
    final myPublicKey = await E2eeKeyStore.getPublicKey();
    if (myPublicKey == null) return;

    final recipients = memberUids.contains(currentUid)
        ? memberUids
        : [...memberUids, currentUid];

    debugPrint('[E2EE] distributing group key to ${recipients.length} member(s)');

    await Future.wait(
      recipients.map((uid) => _wrapAndStoreGroupKey(
            conversationPath: conversationPath,
            groupKey: groupKey,
            recipientUid: uid,
            senderPrivateKey: myPrivateKey,
            senderPublicKey: myPublicKey,
            senderUid: currentUid,
            forceServer: forceServer,
          )),
      eagerError: false,
    );
  }

  static Future<void> _wrapAndStoreGroupKey({
    required String conversationPath,
    required Uint8List groupKey,
    required String recipientUid,
    required String senderPrivateKey,
    required String senderPublicKey,
    required String senderUid,
    bool forceServer = false,
  }) async {
    try {
      // Skip if doc already exists — unless forceServer (regeneration).
      if (!forceServer) {
        final existing = await _firestore
            .collection('$conversationPath/groupKey')
            .doc(recipientUid)
            .get();
        if (existing.exists) return;
      }

      final recipientPublicKey = await _getPublicKey(
        recipientUid,
        forceServer: forceServer,
      );
      if (recipientPublicKey == null) {
        debugPrint('[E2EE] no public key for $recipientUid — skipping');
        return;
      }

      final wrapped = await E2eeCrypto.wrapGroupKey(
        groupKey: groupKey,
        senderPrivateKeyB64: senderPrivateKey,
        recipientPublicKeyB64: recipientPublicKey,
        info: 'govchat:group:$conversationPath',
      );

      await _firestore
          .collection('$conversationPath/groupKey')
          .doc(recipientUid)
          .set({
        'wrappedKey': wrapped.ciphertext,
        'nonce': wrapped.nonce,
        'creatorUid': senderUid,
        'creatorPublicKey': senderPublicKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[E2EE] group key distributed to $recipientUid');
    } catch (e) {
      debugPrint('[E2EE] _wrapAndStoreGroupKey FAILED for $recipientUid: $e');
    }
  }

  static void _distributeGroupKeyBackground({
    required String conversationPath,
    required Uint8List groupKey,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
  }) {
    _distributeGroupKey(
      conversationPath: conversationPath,
      groupKey: groupKey,
      currentUid: currentUid,
      memberUids: memberUids,
      myPrivateKey: myPrivateKey,
    ).ignore();
  }

  /// Distribute the cached group key to a newly added member.
  static Future<void> distributeToNewMember({
    required String conversationPath,
    required String newMemberUid,
  }) async {
    final groupKey = await E2eeKeyStore.getConversationKey(conversationPath);
    if (groupKey == null) return;
    final myPrivateKey = await E2eeKeyStore.getPrivateKey();
    final myPublicKey = await E2eeKeyStore.getPublicKey();
    if (myPrivateKey == null || myPublicKey == null) return;

    await _wrapAndStoreGroupKey(
      conversationPath: conversationPath,
      groupKey: groupKey,
      recipientUid: newMemberUid,
      senderPrivateKey: myPrivateKey,
      senderPublicKey: myPublicKey,
      senderUid: currentUid ?? '',
    );
  }

  // ── Message Encrypt / Decrypt ──────────────────────────────────────────────

  static Future<EncryptedPayload> encryptMessage(
    String plaintext,
    Uint8List key, {
    String? messageHint,
  }) async {
    return E2eeCrypto.encrypt(plaintext, key);
  }

  /// Decrypt a message.  Throws [SecretBoxAuthenticationError] on wrong key.
  static Future<String> decryptMessage(
    EncryptedPayload payload,
    Uint8List key, {
    String? messageId,
  }) async {
    return E2eeCrypto.decrypt(payload, key);
  }

  // ── Key Restore from Backup ───────────────────────────────────────────────

  /// Restore is DISABLED to prevent stale keys from causing MAC failures
  /// after reinstall.  The app always generates a fresh X25519 key pair.
  /// Backup *creation* in [E2eeBackupService.backupPrivateKey] still works.
  static Future<void> restoreKeyFromBackup(
    String uid,
    String privateKeyB64,
  ) async {
    debugPrint('[E2EE] restoreKeyFromBackup DISABLED — '
        'ignoring old key for $uid. '
        'A fresh key pair will be generated by initializeKeys().');
  }

  // ── Logout / Cleanup ───────────────────────────────────────────────────────

  static void clearCache() => E2eeKeyStore.clearCache();

  // ── Public Key Firestore helpers ───────────────────────────────────────────

  /// Fetch another user's X25519 public key from Firestore.
  ///
  /// When [forceServer] is true, bypasses the Firestore SDK local cache
  /// to ensure we get the user's CURRENT key (critical after reinstall).
  static Future<String?> _getPublicKey(
    String uid, {
    bool forceServer = false,
  }) async {
    final GetOptions? opts =
        forceServer ? const GetOptions(source: Source.server) : null;

    // 1. users/{uid}
    try {
      final snap = opts != null
          ? await _firestore.collection('users').doc(uid).get(opts)
          : await _firestore.collection('users').doc(uid).get();
      final key = snap.data()?['e2eePublicKey'] as String?;
      if (key != null) return key;
    } catch (e) {
      debugPrint('[E2EE] _getPublicKey($uid) users/ error: $e');
    }

    // 2. employees/{uid}
    try {
      final snap = opts != null
          ? await _firestore.collection('employees').doc(uid).get(opts)
          : await _firestore.collection('employees').doc(uid).get();
      final key = snap.data()?['e2eePublicKey'] as String?;
      if (key != null) return key;
    } catch (e) {
      debugPrint('[E2EE] _getPublicKey($uid) employees/ error: $e');
    }

    debugPrint('[E2EE] no public key found for $uid');
    return null;
  }

  /// Ensures the public key in Firestore matches the local key.
  /// If Firestore has a stale key from a previous install, it is overwritten.
  static Future<void> _ensurePublicKeyInFirestore(
    String uid,
    String publicKey,
  ) async {
    bool matches = false;
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final stored = snap.data()?['e2eePublicKey'] as String?;
      if (stored == publicKey) {
        matches = true;
      }
    } catch (_) {}

    if (!matches) {
      try {
        final snap = await _firestore.collection('employees').doc(uid).get();
        final stored = snap.data()?['e2eePublicKey'] as String?;
        if (stored == publicKey) {
          matches = true;
        }
      } catch (_) {}
    }

    if (!matches) {
      await _uploadPublicKey(uid, publicKey);
      debugPrint('[E2EE] public key in Firestore updated to match local key for $uid');
    }
  }

  static Future<void> _uploadPublicKey(String uid, String publicKey) async {
    final payload = {
      'e2eePublicKey': publicKey,
      'e2eeKeyUpdatedAt': FieldValue.serverTimestamp(),
    };

    bool wroteAny = false;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
      wroteAny = true;
    } catch (e) {
      debugPrint('[E2EE] users/$uid write failed: $e');
    }

    try {
      await _firestore
          .collection('employees')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
      wroteAny = true;
    } catch (e) {
      debugPrint('[E2EE] employees/$uid write failed: $e');
    }

    if (!wroteAny) {
      throw StateError('[E2EE] Could not write public key for $uid');
    }
  }
}
