import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'e2ee_backup_service.dart';
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

  // ── Shared decrypt cache ────────────────────────────────────────────────────
  //
  // A global in-memory cache of decrypted message text keyed by Firestore
  // document ID.  Shared between the conversation list preview and the chat
  // screen so that a message decrypted in the inbox is immediately available
  // when the user opens the full chat — no re-decrypt or timing race.

  static final Map<String, String> _decryptCache = {};

  /// Store a decrypted plaintext for [messageId].
  static void cacheDecryptedText(String messageId, String plaintext) {
    _decryptCache[messageId] = plaintext;
  }

  /// Retrieve a previously decrypted plaintext for [messageId].
  /// Returns null if not cached.
  static String? getCachedDecryptedText(String messageId) {
    return _decryptCache[messageId];
  }

  /// Clear the shared decrypt cache (e.g., on logout).
  static void clearDecryptCache() {
    _decryptCache.clear();
  }

  // ── Init tracking ──────────────────────────────────────────────────────────
  static Completer<void>? _initCompleter;

  /// True when the user has no local keys but a Firestore backup exists.
  /// The UI should prompt for the backup password when this is set.
  static bool backupAvailable = false;

  /// Set to true immediately after a successful restore.  Cleared after
  /// the first successful conversation key retrieval.  While true, the
  /// group-key unwrap failure path does NOT delete the Firestore doc —
  /// instead it retries with forceServer, giving the restored key a fair
  /// chance to work.
  static bool _justRestored = false;

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

  /// Call once after sign-in.  Ensures an X25519 key pair exists locally
  /// and is published to Firestore.
  ///
  /// When no local keys exist but a cloud backup is found, sets
  /// [backupAvailable] to `true` and returns **without generating fresh
  /// keys**.  The caller MUST check this flag and either:
  ///   1. Call [restoreKeyFromBackup] with the user's password, OR
  ///   2. Call [generateFreshKeys] to create new keys (old messages lost).
  ///
  /// This prevents fresh keys from being published to Firestore before
  /// the user has a chance to restore — which would overwrite their
  /// backed-up public key and break group key unwrapping.
  static Future<void> initializeKeys(String uid) async {
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      // Bootstrap the persistent conversation key index so that backup
      // operations later in this session have a complete picture.
      await E2eeKeyStore.loadIndexIntoMemory();

      final hasKeys = await E2eeKeyStore.hasKeyPair();

      if (hasKeys) {
        debugPrint('[E2EE] X25519 key pair already exists in secure storage');
        backupAvailable = false;
        final pubKey = await E2eeKeyStore.getPublicKey();
        if (pubKey != null) {
          await _ensurePublicKeyInFirestore(uid, pubKey);
        }
        completer.complete();
        return;
      }

      // No local key pair — check for a cloud backup BEFORE generating
      // anything.  If a backup exists, we MUST NOT generate fresh keys
      // yet because publishing a fresh public key to Firestore would
      // overwrite the old one, making group key docs unwrappable only
      // with the fresh key (which the user is about to replace).
      try {
        backupAvailable = await E2eeBackupService.hasBackup(uid);
      } catch (e) {
        debugPrint('[E2EE] backup check failed: $e');
        backupAvailable = false;
      }

      if (backupAvailable) {
        debugPrint(
          '[E2EE] Backup found for $uid — '
          'deferring key generation until restore decision',
        );
        // Complete the init — the caller will handle restore or fresh gen.
        completer.complete();
        return;
      }

      // No backup available — generate fresh keys immediately.
      await _generateAndPublishFreshKeys(uid);
      completer.complete();
    } catch (e) {
      debugPrint('[E2EE] initializeKeys error: $e');
      completer.completeError(e);
    }
  }

  /// Generate a fresh X25519 key pair, save locally, and publish to Firestore.
  ///
  /// Called when no backup exists, or when the user explicitly skips restore.
  /// After this call, old private-chat messages are permanently undecryptable.
  static Future<void> generateFreshKeys(String uid) async {
    await _generateAndPublishFreshKeys(uid);
    backupAvailable = false;
  }

  static Future<void> _generateAndPublishFreshKeys(String uid) async {
    debugPrint('[E2EE] Generating FRESH X25519 keys for $uid ...');
    final keyPair = await E2eeCrypto.generateKeyPair();

    await E2eeKeyStore.saveKeyPair(
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
    );
    await _uploadPublicKey(uid, keyPair.publicKey);

    // Clear any stale conversation AES keys that were derived with old
    // identity keys.  They will be re-derived using the new key pair.
    await E2eeKeyStore.clearConversationKeys();

    debugPrint('[E2EE] Fresh X25519 key pair generated and published for $uid');
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
    debugPrint(
      '[E2EE] getConversationKey  path=$conversationPath  '
      'private=$isPrivateChat  forceRefresh=$forceRefresh',
    );

    // ── 1. Check local cache / storage ─────────────────────────────────────
    if (forceRefresh) {
      // For group chats, the AES key is a random key that cannot be
      // re-derived from identity keys — it can only come from the Firestore
      // wrapped-key doc or from a backup.  Do NOT remove it preemptively;
      // instead, check if a key exists and return it.  Only wipe the key
      // when the caller has evidence it is wrong (MAC errors trigger a
      // separate removeConversationKey + forceRefresh cycle).
      if (!isPrivateChat) {
        final existingKey = await E2eeKeyStore.getConversationKey(
          conversationPath,
        );
        if (existingKey != null) {
          debugPrint(
            '[E2EE] forceRefresh: group key preserved from cache '
            '(${existingKey.length} B)',
          );
          _justRestored = false;
          return existingKey;
        }
        debugPrint(
          '[E2EE] forceRefresh: no cached group key — will fetch/create',
        );
      } else {
        // Private chat keys CAN be re-derived from identity keys, so
        // it is safe to remove and re-derive.
        await E2eeKeyStore.removeConversationKey(conversationPath);
      }
    } else {
      final cached = await E2eeKeyStore.getConversationKey(conversationPath);
      if (cached != null) {
        debugPrint('[E2EE] conversation key loaded from cache');
        _justRestored = false; // Restore is proven working.
        return cached;
      }
    }

    // ── 2. Load own private key ────────────────────────────────────────────
    var myPrivateKey = await E2eeKeyStore.getPrivateKey();
    if (myPrivateKey == null) {
      // Safety net: if no private key exists (e.g., app restart after failed
      // restore, or secure storage cleared), generate fresh keys so the user
      // can at least participate going forward.
      debugPrint(
        '[E2EE] no local private key — attempting emergency key generation',
      );
      try {
        await _generateAndPublishFreshKeys(currentUid);
        myPrivateKey = await E2eeKeyStore.getPrivateKey();
      } catch (e) {
        debugPrint('[E2EE] emergency key generation failed: $e');
      }
      if (myPrivateKey == null) {
        debugPrint('[E2EE] still no private key after generation — giving up');
        return null;
      }
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

    debugPrint(
      '[E2EE] private chat: deriving key with $otherUid'
      '${forceServer ? ' (server fetch)' : ''}',
    );

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
      _autoRefreshBackup().ignore();
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
    debugPrint(
      '[E2EE] _getOrCreateGroupKey START  '
      'path=$conversationPath  uid=$currentUid  '
      'members=${memberUids.length}  forceServer=$forceServer',
    );

    final groupKeyCol = _firestore.collection('$conversationPath/groupKey');
    final myDocRef = groupKeyCol.doc(currentUid);

    // NOTE: The atomic _lock transaction in STEP 2 guarantees exactly one
    // device generates the group key.  Background re-distribution by
    // different members is legitimate and changes creatorUid/creatorPublicKey
    // per-doc, so a pre-scan comparing those fields would false-positive.
    // The lock is the authoritative race-condition guard.

    // ── STEP 1: Try own Firestore doc (fast path) ─────────────────────────
    try {
      // First try with SDK cache, then force server if unwrap fails.
      // This handles the case where the doc was re-wrapped after reinstall
      // but the SDK cache still has the old version.
      var myDoc = await myDocRef.get();

      // If forceServer requested and doc exists, re-fetch from server.
      if (myDoc.exists && forceServer) {
        myDoc = await myDocRef.get(const GetOptions(source: Source.server));
      }

      if (myDoc.exists) {
        var key = await _unwrapAndSave(
          conversationPath: conversationPath,
          currentUid: currentUid,
          data: myDoc.data()!,
          myPrivateKey: myPrivateKey,
          memberUids: memberUids,
        );
        if (key != null) return key;

        // Unwrap failed with cached doc — retry from server in case
        // the doc was re-wrapped with our current public key.
        if (!forceServer) {
          debugPrint('[E2EE] unwrap failed (cache) — retrying from server');
          final serverDoc = await myDocRef.get(
            const GetOptions(source: Source.server),
          );
          if (serverDoc.exists) {
            key = await _unwrapAndSave(
              conversationPath: conversationPath,
              currentUid: currentUid,
              data: serverDoc.data()!,
              myPrivateKey: myPrivateKey,
              memberUids: memberUids,
            );
            if (key != null) return key;
          }
        }

        // Unwrap failed.  If we just restored from backup, the identity key
        // SHOULD be correct — the failure likely means the doc was wrapped with
        // a different creator key (e.g., another member re-distributed while we
        // were offline).  Wait for re-distribution rather than deleting.
        if (_justRestored) {
          debugPrint(
            '[E2EE] unwrap failed post-restore — NOT deleting doc. '
            'Will wait for re-distribution or retry.',
          );
          // Clear the flag so subsequent calls can take normal action.
          _justRestored = false;
          return null;
        }

        // Normal (non-restore) unwrap failure — our identity key has changed
        // (e.g. reinstall with stale backup or fresh key generation).
        // Delete ALL groupKey docs + lock, then directly generate a fresh key.
        // This ensures the group recovers even when no other member is online.
        // Old messages encrypted with the previous key are lost for this user,
        // but the group becomes functional again.
        debugPrint(
          '[E2EE] unwrap failed — self-healing: purging all group key docs '
          'and generating fresh key',
        );
        try {
          // Delete all group key docs (stale wrapped keys for all members).
          final allDocs = await groupKeyCol.get();
          for (final doc in allDocs.docs) {
            await doc.reference.delete();
          }
          debugPrint(
            '[E2EE] deleted ${allDocs.docs.length} group key doc(s) + lock',
          );
        } catch (cleanupErr) {
          debugPrint('[E2EE] cleanup error: $cleanupErr');
        }

        // Directly generate and distribute — skip the lock transaction since
        // we just proved membership by having a doc, and we've cleared all
        // state so no race condition is possible.
        try {
          final freshKey = await E2eeCrypto.generateGroupKey();
          final myPublicKey = await E2eeKeyStore.getPublicKey();

          if (myPublicKey != null) {
            // Re-acquire lock for consistency.
            await _firestore.doc('$conversationPath/groupKey/_lock').set({
              'creatorUid': currentUid,
              'createdAt': FieldValue.serverTimestamp(),
            });

            await _distributeGroupKey(
              conversationPath: conversationPath,
              groupKey: freshKey,
              currentUid: currentUid,
              memberUids: memberUids,
              myPrivateKey: myPrivateKey,
              forceServer: true,
            );
          }

          await E2eeKeyStore.saveConversationKey(conversationPath, freshKey);
          debugPrint(
            '[E2EE] self-heal complete — fresh group key created '
            '(${freshKey.length} bytes)',
          );
          _autoRefreshBackup().ignore();
          return freshKey;
        } catch (e) {
          debugPrint('[E2EE] self-heal key generation failed: $e');
          return null;
        }
      }
    } catch (e) {
      debugPrint('[E2EE] failed to read own group key doc: $e');
    }

    // ── STEP 2: Atomic lock — only ONE device generates the group key ─────
    debugPrint('[E2EE] STEP 2: attempting lock transaction');
    final lockRef = _firestore.doc('$conversationPath/groupKey/_lock');
    final candidateKey = await E2eeCrypto.generateGroupKey();

    bool weWon = false;

    try {
      await _firestore.runTransaction((txn) async {
        final lockSnap = await txn.get(lockRef);
        debugPrint('[E2EE] lock exists=${lockSnap.exists}');
        if (!lockSnap.exists) {
          txn.set(lockRef, {
            'creatorUid': currentUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          weWon = true;
        } else {
          weWon = false;
          final lockData = lockSnap.data();
          debugPrint(
            '[E2EE] lock held by ${lockData?['creatorUid']}',
          );
        }
      });
    } catch (e, st) {
      debugPrint('[E2EE] lock transaction FAILED: $e\n$st');
    }
    debugPrint('[E2EE] lock result: weWon=$weWon');

    // ── STEP 3a: We WON — distribute to all members ──────────────────────
    if (weWon) {
      debugPrint(
        '[E2EE] STEP 3a: won lock — distributing to '
        '${memberUids.length} members',
      );
      try {
        await _distributeGroupKey(
          conversationPath: conversationPath,
          groupKey: candidateKey,
          currentUid: currentUid,
          memberUids: memberUids,
          myPrivateKey: myPrivateKey,
          forceServer: true,
        );
        debugPrint('[E2EE] distribution complete — saving key locally');

        await E2eeKeyStore.saveConversationKey(conversationPath, candidateKey);
        debugPrint(
          '[E2EE] group key CREATED and SAVED (${candidateKey.length} bytes)',
        );
        _autoRefreshBackup().ignore();
        return candidateKey;
      } catch (e, st) {
        debugPrint('[E2EE] STEP 3a FAILED: $e\n$st');
        // Even if distribution fails, save locally so THIS device can work.
        try {
          await E2eeKeyStore.saveConversationKey(
            conversationPath,
            candidateKey,
          );
          debugPrint('[E2EE] saved key locally despite distribution failure');
          return candidateKey;
        } catch (_) {}
        return null;
      }
    }

    // ── STEP 3b: We LOST — wait for distribution ──────────────────────────
    debugPrint('[E2EE] STEP 3b: lost lock — polling for distribution');

    for (int attempt = 1; attempt <= 3; attempt++) {
      await Future.delayed(Duration(seconds: attempt));
      try {
        final retryDoc = await myDocRef.get(
          const GetOptions(source: Source.server),
        );
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

    // Lock holder didn't distribute to us — the lock may be stale (creator
    // crashed, lost network, or this user wasn't in their member list).
    // Take over: delete stale lock + generate key ourselves.
    debugPrint(
      '[E2EE] distribution timed out — taking over group key creation',
    );
    try {
      await lockRef.delete();
      final freshKey = await E2eeCrypto.generateGroupKey();
      await lockRef.set({
        'creatorUid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final myPublicKey = await E2eeKeyStore.getPublicKey();
      if (myPublicKey != null) {
        await _distributeGroupKey(
          conversationPath: conversationPath,
          groupKey: freshKey,
          currentUid: currentUid,
          memberUids: memberUids,
          myPrivateKey: myPrivateKey,
          forceServer: true,
        );
      }

      await E2eeKeyStore.saveConversationKey(conversationPath, freshKey);
      debugPrint('[E2EE] takeover complete — group key created');
      _autoRefreshBackup().ignore();
      return freshKey;
    } catch (e) {
      debugPrint('[E2EE] takeover failed: $e');
      return null;
    }
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
    final creatorUid = data['creatorUid'] as String?;

    if (wrappedKey == null || nonce == null || creatorPublicKey == null) {
      debugPrint(
        '[E2EE] groupKey doc missing required fields '
        '(wrapped=${wrappedKey != null}, nonce=${nonce != null}, '
        'creatorPub=${creatorPublicKey != null})',
      );
      return null;
    }

    // Diagnostic: log key fingerprints for debugging unwrap failures.
    final myPublicKey = await E2eeKeyStore.getPublicKey();
    debugPrint(
      '[E2EE] unwrap attempt: '
      'myPub=${myPublicKey?.substring(0, 8) ?? "null"}… '
      'creatorPub=${creatorPublicKey.substring(0, 8)}… '
      'creatorUid=$creatorUid '
      'path=$conversationPath',
    );

    try {
      final groupKey = await E2eeCrypto.unwrapGroupKey(
        wrappedKey: EncryptedPayload(ciphertext: wrappedKey, nonce: nonce),
        myPrivateKeyB64: myPrivateKey,
        senderPublicKeyB64: creatorPublicKey,
        info: 'govchat:group:$conversationPath',
      );

      await E2eeKeyStore.saveConversationKey(conversationPath, groupKey);
      debugPrint(
        '[E2EE] group key unwrapped and saved (${groupKey.length} bytes)',
      );
      _autoRefreshBackup().ignore();

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
      debugPrint('[E2EE] unwrap FAILED: $e');
      debugPrint(
        '[E2EE] unwrap diag: myPriv=${myPrivateKey.substring(0, 8)}… '
        'myPub=${myPublicKey?.substring(0, 8) ?? "null"}… '
        'creatorPub=${creatorPublicKey.substring(0, 8)}… '
        'isSelf=${creatorUid == currentUid}',
      );
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

    debugPrint(
      '[E2EE] distributing group key to ${recipients.length} member(s)',
    );

    await Future.wait(
      recipients.map(
        (uid) => _wrapAndStoreGroupKey(
          conversationPath: conversationPath,
          groupKey: groupKey,
          recipientUid: uid,
          senderPrivateKey: myPrivateKey,
          senderPublicKey: myPublicKey,
          senderUid: currentUid,
          forceServer: forceServer,
        ),
      ),
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

  // ── Key Backup ─────────────────────────────────────────────────────────────

  /// Create a full E2EE backup containing identity key + all conversation keys.
  ///
  /// Called from the profile screen's backup button.  The manifest includes
  /// every conversation AES key currently in secure storage so that after
  /// reinstall + restore, messages can be decrypted immediately without
  /// re-derivation.
  static Future<BackupManifest> createBackup({
    required String uid,
    required String password,
  }) async {
    final privateKey = await E2eeKeyStore.getPrivateKey();
    if (privateKey == null) {
      throw StateError('Cannot create backup — no private key in storage');
    }

    final publicKey = await E2eeKeyStore.getPublicKey();
    final convEntries = await E2eeKeyStore.getAllConversationEntries();

    final manifest = BackupManifest(
      version: 2,
      userId: uid,
      identityPrivateKey: privateKey,
      identityPublicKeyFingerprint: publicKey != null && publicKey.length >= 8
          ? publicKey.substring(0, 8)
          : publicKey,
      conversationKeys: convEntries,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    await E2eeBackupService.createBackup(
      uid: uid,
      manifest: manifest,
      password: password,
    );

    debugPrint(
      '[E2EE] full backup created: '
      '${convEntries.length} conversation key(s)',
    );
    return manifest;
  }

  /// Silently refresh the cloud backup with the latest conversation keys.
  ///
  /// Called in the background after a new conversation key is derived or
  /// unwrapped.  Uses the stored backup password from the current session
  /// (if available).  Fire-and-forget — failures are logged but not
  /// propagated.
  static String? _lastBackupPassword;

  /// Store the backup password so auto-refresh can use it.
  static void setBackupPassword(String password) {
    _lastBackupPassword = password;
  }

  /// Attempt to silently refresh the backup.  No-op if no password is cached.
  static Future<void> _autoRefreshBackup() async {
    final uid = currentUid;
    final password = _lastBackupPassword;
    if (uid == null || password == null) return;

    try {
      final hasBackup = await E2eeBackupService.hasBackup(uid);
      if (!hasBackup) return; // User hasn't enabled backup.

      await createBackup(uid: uid, password: password);
      debugPrint('[E2EE] auto-refresh backup completed');
    } catch (e) {
      debugPrint('[E2EE] auto-refresh backup failed (non-critical): $e');
    }
  }

  // ── Key Restore from Backup ───────────────────────────────────────────────

  /// Restore E2EE keys from a [BackupManifest].
  ///
  /// Restores the identity key pair AND all conversation AES keys from the
  /// manifest.  Conversation keys are written back to secure storage with
  /// the exact same storage-key identifiers so that [getConversationKey]
  /// finds them without re-derivation.
  ///
  /// Returns a [RestoreResult] with diagnostics.
  static Future<RestoreResult> restoreFromManifest(
    String uid,
    BackupManifest manifest,
  ) async {
    debugPrint(
      '[E2EE] restoreFromManifest: restoring for $uid '
      '(v${manifest.version}, ${manifest.conversationKeys.length} conv keys)',
    );

    // 1. Restore identity key pair.
    final publicKeyB64 = await E2eeCrypto.derivePublicKeyFromPrivate(
      manifest.identityPrivateKey,
    );

    await E2eeKeyStore.saveKeyPair(
      publicKey: publicKeyB64,
      privateKey: manifest.identityPrivateKey,
    );
    await _uploadPublicKey(uid, publicKeyB64);

    // 2. Verify restored public key matches manifest fingerprint (if present).
    bool fingerprintMatch = true;
    if (manifest.identityPublicKeyFingerprint != null &&
        publicKeyB64.length >= 8) {
      fingerprintMatch =
          publicKeyB64.substring(0, 8) == manifest.identityPublicKeyFingerprint;
      if (!fingerprintMatch) {
        debugPrint(
          '[E2EE] WARNING: restored public key fingerprint mismatch! '
          'expected=${manifest.identityPublicKeyFingerprint} '
          'got=${publicKeyB64.substring(0, 8)}',
        );
      }
    }

    // 3. Clear stale conversation keys, then restore from manifest.
    await E2eeKeyStore.clearConversationKeys();

    // Log group key diagnostics.
    int groupKeyCount = 0;
    int privateKeyCount = 0;
    for (final storageKey in manifest.conversationKeys.keys) {
      if (storageKey.startsWith(E2eeKeyStore.convKeyPrefix)) {
        try {
          final encoded = storageKey.substring(
            E2eeKeyStore.convKeyPrefix.length,
          );
          final path = utf8.decode(base64Url.decode(encoded));
          if (path.contains('/private_chats/')) {
            privateKeyCount++;
          } else {
            groupKeyCount++;
          }
          debugPrint('[E2EE] restore key: $path');
        } catch (_) {
          // Legacy key — can't decode path.
          groupKeyCount++; // Count as group (conservative).
        }
      }
    }
    debugPrint(
      '[E2EE] manifest breakdown: '
      '${manifest.conversationKeys.length} total, '
      '$privateKeyCount private, $groupKeyCount group/dept/org',
    );

    int restoredConvKeys = 0;
    int verifiedConvKeys = 0;
    if (manifest.conversationKeys.isNotEmpty) {
      restoredConvKeys = await E2eeKeyStore.restoreConversationKeys(
        manifest.conversationKeys,
      );

      // 3b. Verify that writes actually persisted (catches silent storage
      // failures on some Android devices).
      verifiedConvKeys = await E2eeKeyStore.verifyRestoredKeys();
      if (verifiedConvKeys < restoredConvKeys) {
        debugPrint(
          '[E2EE] WARNING: only $verifiedConvKeys/$restoredConvKeys '
          'conversation keys verified readable after restore',
        );
      }
    }

    // Mark that restore happened — used by getConversationKey to avoid
    // deleting group key docs on first unwrap failure.
    _justRestored = true;

    backupAvailable = false;

    debugPrint(
      '[E2EE] restore complete: pub=${publicKeyB64.substring(0, 8)}… '
      'convKeys=$restoredConvKeys/${manifest.conversationKeys.length}',
    );

    return RestoreResult(
      restoredPublicKey: publicKeyB64,
      fingerprintMatch: fingerprintMatch,
      manifestVersion: manifest.version,
      conversationKeysInManifest: manifest.conversationKeys.length,
      conversationKeysRestored: restoredConvKeys,
      conversationKeysVerified: verifiedConvKeys,
    );
  }

  /// Legacy restore — accepts just the private key (for old-format backups).
  ///
  /// Returns the restored public key (base64) for diagnostic display.
  static Future<String> restoreKeyFromBackup(
    String uid,
    String privateKeyB64,
  ) async {
    final result = await restoreFromManifest(
      uid,
      BackupManifest(
        version: 1,
        userId: uid,
        identityPrivateKey: privateKeyB64,
        identityPublicKeyFingerprint: null,
        conversationKeys: {},
        createdAt: null,
      ),
    );
    return result.restoredPublicKey;
  }

  /// Verify that a restored key can actually derive a valid conversation key.
  ///
  /// Attempts to derive/unwrap the conversation key for [conversationPath].
  /// Returns a diagnostic map with the result.
  static Future<Map<String, dynamic>> validateRestore({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required bool isPrivateChat,
  }) async {
    final sw = Stopwatch()..start();
    final result = <String, dynamic>{
      'conversationPath': conversationPath,
      'isPrivateChat': isPrivateChat,
    };

    try {
      final privateKey = await E2eeKeyStore.getPrivateKey();
      result['hasPrivateKey'] = privateKey != null;
      if (privateKey == null) {
        result['error'] = 'No private key in storage';
        return result;
      }

      final publicKey = await E2eeKeyStore.getPublicKey();
      result['publicKeyPrefix'] = publicKey?.substring(0, 8);

      final key = await getConversationKey(
        conversationPath: conversationPath,
        currentUid: currentUid,
        memberUids: memberUids,
        isPrivateChat: isPrivateChat,
        forceRefresh: true,
      );

      result['keyDerived'] = key != null;
      result['keyLength'] = key?.length;
      result['elapsed_ms'] = sw.elapsedMilliseconds;
    } catch (e) {
      result['error'] = e.toString();
      result['elapsed_ms'] = sw.elapsedMilliseconds;
    }

    debugPrint('[E2EE] validateRestore: $result');
    return result;
  }

  // ── Diagnostics ────────────────────────────────────────────────────────────

  /// Returns a diagnostic snapshot of the E2EE subsystem state.
  /// Safe to call at any time — never mutates state.
  static Future<Map<String, dynamic>> diagnostics() async {
    final uid = currentUid;
    final hasLocal = await E2eeKeyStore.hasKeyPair();
    final localPubKey = await E2eeKeyStore.getPublicKey();

    String? firestorePubKey;
    bool firestoreMatch = false;
    if (uid != null) {
      firestorePubKey = await _getPublicKey(uid, forceServer: true);
      firestoreMatch =
          firestorePubKey != null &&
          localPubKey != null &&
          firestorePubKey == localPubKey;
    }

    bool hasCloudBackup = false;
    if (uid != null) {
      try {
        hasCloudBackup = await E2eeBackupService.hasBackup(uid);
      } catch (_) {}
    }

    // Count cached conversation keys by type.
    final allEntries = await E2eeKeyStore.getAllConversationEntries();
    int groupKeys = 0;
    int privateChatKeys = 0;
    for (final storageKey in allEntries.keys) {
      if (storageKey.startsWith(E2eeKeyStore.convKeyPrefix)) {
        try {
          final encoded = storageKey.substring(
            E2eeKeyStore.convKeyPrefix.length,
          );
          final path = utf8.decode(base64Url.decode(encoded));
          if (path.contains('/private_chats/')) {
            privateChatKeys++;
          } else {
            groupKeys++;
          }
        } catch (_) {
          groupKeys++;
        }
      }
    }

    return {
      'version': 2,
      'uid': uid,
      'hasLocalKeyPair': hasLocal,
      'localPublicKeyPrefix': localPubKey != null
          ? '${localPubKey.substring(0, 8)}...'
          : null,
      'firestorePublicKeyPrefix': firestorePubKey != null
          ? '${firestorePubKey.substring(0, 8)}...'
          : null,
      'firestoreKeyMatchesLocal': firestoreMatch,
      'hasCloudBackup': hasCloudBackup,
      'backupAvailableFlag': backupAvailable,
      'initCompleterDone': _initCompleter?.isCompleted ?? true,
      'justRestored': _justRestored,
      'totalConversationKeys': allEntries.length,
      'groupKeys': groupKeys,
      'privateChatKeys': privateChatKeys,
      'hasBackupPassword': _lastBackupPassword != null,
    };
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
    final GetOptions? opts = forceServer
        ? const GetOptions(source: Source.server)
        : null;

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
      debugPrint(
        '[E2EE] public key in Firestore updated to match local key for $uid',
      );
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

// ── Restore Result ───────────────────────────────────────────────────────────

/// Diagnostic result from [E2eeManager.restoreFromManifest].
class RestoreResult {
  final String restoredPublicKey;
  final bool fingerprintMatch;
  final int manifestVersion;
  final int conversationKeysInManifest;
  final int conversationKeysRestored;
  final int conversationKeysVerified;

  const RestoreResult({
    required this.restoredPublicKey,
    required this.fingerprintMatch,
    required this.manifestVersion,
    required this.conversationKeysInManifest,
    required this.conversationKeysRestored,
    this.conversationKeysVerified = 0,
  });

  bool get hasConversationKeys => conversationKeysRestored > 0;

  /// True if all restored keys could be verified as readable from storage.
  bool get allKeysVerified =>
      conversationKeysRestored == 0 ||
      conversationKeysVerified >= conversationKeysRestored;

  Map<String, dynamic> toJson() => {
    'restoredPublicKeyPrefix': restoredPublicKey.length >= 8
        ? restoredPublicKey.substring(0, 8)
        : restoredPublicKey,
    'fingerprintMatch': fingerprintMatch,
    'manifestVersion': manifestVersion,
    'conversationKeysInManifest': conversationKeysInManifest,
    'conversationKeysRestored': conversationKeysRestored,
    'conversationKeysVerified': conversationKeysVerified,
    'allKeysVerified': allKeysVerified,
  };

  @override
  String toString() => 'RestoreResult(${toJson()})';
}
