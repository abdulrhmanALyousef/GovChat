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
///   - `users/{uid}.e2eePublicKey`  — user's X25519 public key (base64)
///   - `employees/{uid}.e2eePublicKey` — fallback location for same key
///   - `{conversationPath}/groupKey/{uid}` — per-member wrapped group key
///       fields: `wrappedKey`, `nonce`, `creatorUid`, `creatorPublicKey`
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
        debugPrint('[E2EE] X25519 key pair already exists — '
            'ensuring public key is in Firestore');
        final pubKey = await E2eeKeyStore.getPublicKey();
        if (pubKey != null) {
          await _ensurePublicKeyInFirestore(uid, pubKey);
        }
        completer.complete();
        return;
      }

      debugPrint('[E2EE] Generating X25519 key pair for $uid ...');
      final keyPair = await E2eeCrypto.generateKeyPair();

      await E2eeKeyStore.saveKeyPair(
        publicKey: keyPair.publicKey,
        privateKey: keyPair.privateKey,
      );
      await _uploadPublicKey(uid, keyPair.publicKey);

      debugPrint('[E2EE] X25519 key pair initialised for $uid');
      completer.complete();
    } catch (e) {
      debugPrint('[E2EE] initializeKeys error: $e');
      completer.completeError(e);
    }
  }

  // ── Conversation Key Retrieval ─────────────────────────────────────────────

  /// Get the AES-256 conversation key for [conversationPath].
  ///
  /// For **private chats**: derives via X25519 key agreement with the other
  /// participant.  The derived key is deterministic — both sides derive the
  /// same key independently without Firestore round-trips.
  ///
  /// For **group chats**: reads or creates a random AES-256 group key wrapped
  /// per-member in Firestore.
  ///
  /// Returns `null` only when keys cannot be obtained (e.g. missing public
  /// key from other participant, Firestore unreachable).
  static Future<Uint8List?> getConversationKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required bool isPrivateChat,
  }) async {
    debugPrint('[E2EE] getConversationKey  path=$conversationPath  '
        'private=$isPrivateChat  uid=$currentUid');

    // ── 1. Check local cache / storage ─────────────────────────────────────
    final cached = await E2eeKeyStore.getConversationKey(conversationPath);
    if (cached != null) {
      debugPrint('[E2EE] conversation key loaded from cache/storage');
      return cached;
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
      );
    } else {
      return _getOrCreateGroupKey(
        conversationPath: conversationPath,
        currentUid: currentUid,
        memberUids: memberUids,
        myPrivateKey: myPrivateKey,
      );
    }
  }

  // ── Private Chat: X25519 Key Agreement ─────────────────────────────────────

  static Future<Uint8List?> _derivePrivateChatKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
  }) async {
    // Find the other participant.
    final otherUid = memberUids.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => currentUid,
    );

    debugPrint('[E2EE] private chat: deriving shared key with $otherUid');

    final theirPublicKey = await _getPublicKey(otherUid);
    if (theirPublicKey == null) {
      debugPrint('[E2EE] no public key for $otherUid — cannot derive key');
      return null;
    }

    try {
      final aesKey = await E2eeCrypto.deriveSharedKey(
        myPrivateKeyB64: myPrivateKey,
        theirPublicKeyB64: theirPublicKey,
        info: 'govchat:private:$conversationPath',
      );

      await E2eeKeyStore.saveConversationKey(conversationPath, aesKey);
      debugPrint('[E2EE] private chat key derived and saved '
          '(${aesKey.length} bytes)');
      return aesKey;
    } catch (e) {
      debugPrint('[E2EE] key derivation failed: $e');
      return null;
    }
  }

  // ── Group Chat: Shared AES Key ─────────────────────────────────────────────

  static Future<Uint8List?> _getOrCreateGroupKey({
    required String conversationPath,
    required String currentUid,
    required List<String> memberUids,
    required String myPrivateKey,
  }) async {
    debugPrint('[E2EE] group chat: looking for existing group key ...');

    // ── Try to load our wrapped copy from Firestore ────────────────────────
    try {
      final myDoc = await _firestore
          .collection('$conversationPath/groupKey')
          .doc(currentUid)
          .get();

      if (myDoc.exists) {
        final data = myDoc.data()!;
        final wrappedPayload = EncryptedPayload(
          ciphertext: data['wrappedKey'] as String,
          nonce: data['nonce'] as String,
        );
        final creatorPublicKey = data['creatorPublicKey'] as String;

        final groupKey = await E2eeCrypto.unwrapGroupKey(
          wrappedKey: wrappedPayload,
          myPrivateKeyB64: myPrivateKey,
          senderPublicKeyB64: creatorPublicKey,
          info: 'govchat:group:$conversationPath',
        );

        await E2eeKeyStore.saveConversationKey(conversationPath, groupKey);
        debugPrint('[E2EE] group key unwrapped and saved '
            '(${groupKey.length} bytes)');

        // Background: ensure all current members have a copy.
        _distributeGroupKeyBackground(
          conversationPath: conversationPath,
          groupKey: groupKey,
          currentUid: currentUid,
          memberUids: memberUids,
          myPrivateKey: myPrivateKey,
        );

        return groupKey;
      }
    } catch (e) {
      debugPrint('[E2EE] failed to read own group key doc: $e');
    }

    // ── Check if ANY group key doc exists (another member created it) ───────
    try {
      final anyDoc = await _firestore
          .collection('$conversationPath/groupKey')
          .limit(1)
          .get();

      if (anyDoc.docs.isNotEmpty) {
        // A group key exists but we don't have our copy yet.
        // Wait briefly for distribution.
        debugPrint('[E2EE] group key exists but not for $currentUid — '
            'waiting for distribution');
        for (int attempt = 1; attempt <= 3; attempt++) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          final retry = await _firestore
              .collection('$conversationPath/groupKey')
              .doc(currentUid)
              .get();
          if (retry.exists) {
            final data = retry.data()!;
            final wrappedPayload = EncryptedPayload(
              ciphertext: data['wrappedKey'] as String,
              nonce: data['nonce'] as String,
            );
            final creatorPublicKey = data['creatorPublicKey'] as String;

            final groupKey = await E2eeCrypto.unwrapGroupKey(
              wrappedKey: wrappedPayload,
              myPrivateKeyB64: myPrivateKey,
              senderPublicKeyB64: creatorPublicKey,
              info: 'govchat:group:$conversationPath',
            );

            await E2eeKeyStore.saveConversationKey(conversationPath, groupKey);
            debugPrint('[E2EE] group key received on retry $attempt');
            return groupKey;
          }
        }
        debugPrint('[E2EE] group key not distributed to us yet — '
            'returning null');
        return null;
      }
    } catch (e) {
      debugPrint('[E2EE] group key existence check failed: $e');
    }

    // ── No group key exists — we are the first member: create one ──────────
    debugPrint('[E2EE] creating new group key for $conversationPath');

    try {
      final groupKey = await E2eeCrypto.generateGroupKey();

      await _distributeGroupKey(
        conversationPath: conversationPath,
        groupKey: groupKey,
        currentUid: currentUid,
        memberUids: memberUids,
        myPrivateKey: myPrivateKey,
      );

      await E2eeKeyStore.saveConversationKey(conversationPath, groupKey);
      debugPrint('[E2EE] group key created and distributed '
          '(${groupKey.length} bytes)');
      return groupKey;
    } catch (e) {
      debugPrint('[E2EE] group key creation failed: $e');
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
  }) async {
    final myPublicKey = await E2eeKeyStore.getPublicKey();
    if (myPublicKey == null) return;

    final recipients = memberUids.contains(currentUid)
        ? memberUids
        : [...memberUids, currentUid];

    debugPrint('[E2EE] distributing group key to '
        '${recipients.length} member(s)');

    await Future.wait(
      recipients.map((uid) => _wrapAndStoreGroupKey(
            conversationPath: conversationPath,
            groupKey: groupKey,
            recipientUid: uid,
            senderPrivateKey: myPrivateKey,
            senderPublicKey: myPublicKey,
            senderUid: currentUid,
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
  }) async {
    try {
      // Don't overwrite if recipient already has a key doc.
      final existing = await _firestore
          .collection('$conversationPath/groupKey')
          .doc(recipientUid)
          .get();
      if (existing.exists) {
        debugPrint('[E2EE] $recipientUid already has group key — skipping');
        return;
      }

      final recipientPublicKey = await _getPublicKey(recipientUid);
      if (recipientPublicKey == null) {
        debugPrint('[E2EE] no public key for $recipientUid — '
            'cannot distribute group key');
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
      debugPrint('[E2EE] _wrapAndStoreGroupKey FAILED for '
          '$recipientUid: $e');
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
    final groupKey =
        await E2eeKeyStore.getConversationKey(conversationPath);
    if (groupKey == null) {
      debugPrint('[E2EE] no cached group key for $conversationPath');
      return;
    }
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

  /// Encrypt a plaintext message.  Returns `{ciphertext, nonce}`.
  static Future<EncryptedPayload> encryptMessage(
    String plaintext,
    Uint8List key,
  ) {
    return E2eeCrypto.encrypt(plaintext, key);
  }

  /// Decrypt a message.  Throws on wrong key / corrupted data.
  static Future<String> decryptMessage(
    EncryptedPayload payload,
    Uint8List key,
  ) {
    return E2eeCrypto.decrypt(payload, key);
  }

  // ── Logout / Cleanup ───────────────────────────────────────────────────────

  /// Clear in-memory caches on logout.  Keys remain in secure storage so
  /// they survive app restarts.
  static void clearCache() => E2eeKeyStore.clearCache();

  // ── Public Key Firestore helpers ───────────────────────────────────────────

  /// Fetch another user's X25519 public key from Firestore.
  static Future<String?> _getPublicKey(String uid) async {
    // 1. users/{uid}
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final key = snap.data()?['e2eePublicKey'] as String?;
      if (key != null) return key;
    } catch (e) {
      debugPrint('[E2EE] _getPublicKey($uid) users/ error: $e');
    }

    // 2. employees/{uid}
    try {
      final snap = await _firestore.collection('employees').doc(uid).get();
      final key = snap.data()?['e2eePublicKey'] as String?;
      if (key != null) return key;
    } catch (e) {
      debugPrint('[E2EE] _getPublicKey($uid) employees/ error: $e');
    }

    debugPrint('[E2EE] no public key found for $uid');
    return null;
  }

  static Future<void> _ensurePublicKeyInFirestore(
    String uid,
    String publicKey,
  ) async {
    bool found = false;
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      found = snap.data()?['e2eePublicKey'] != null;
    } catch (_) {}

    if (!found) {
      try {
        final snap = await _firestore.collection('employees').doc(uid).get();
        found = snap.data()?['e2eePublicKey'] != null;
      } catch (_) {}
    }

    if (!found) {
      await _uploadPublicKey(uid, publicKey);
      debugPrint('[E2EE] restored public key to Firestore for $uid');
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
      debugPrint('[E2EE] public key written to users/$uid');
      wroteAny = true;
    } catch (e) {
      debugPrint('[E2EE] users/$uid write failed: $e');
    }

    try {
      await _firestore
          .collection('employees')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
      debugPrint('[E2EE] public key written to employees/$uid');
      wroteAny = true;
    } catch (e) {
      debugPrint('[E2EE] employees/$uid write failed: $e');
    }

    if (!wroteAny) {
      throw StateError('[E2EE] Could not write public key for $uid');
    }
  }
}
