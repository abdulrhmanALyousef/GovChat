import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'aes_service.dart';
import 'key_management_service.dart';
import 'rsa_service.dart';

/// Manages per-conversation (department) AES-256 session keys.
///
/// Design:
///   • One AES-256 key per department conversation, stored encrypted in
///     Firestore at `organizations/{orgId}/departments/{deptId}/conversationKeys/{uid}`.
///   • Each department member stores their own copy of the key, wrapped with
///     their RSA public key (hybrid encryption).
///   • Decryption only requires the member's private key — Firebase never sees
///     the plaintext AES key.
///   • An in-memory cache avoids repeated Firestore + RSA operations within a
///     single session.
class ConversationKeyService {
  ConversationKeyService._();

  static final _firestore = FirebaseFirestore.instance;

  // conversationId → plaintext AES key bytes
  static final Map<String, Uint8List> _cache = {};

  // ── Main entry ───────────────────────────────────────────────────────────────

  /// Return the plaintext AES-256 key for a department conversation.
  ///
  /// Flow:
  ///   1. Return cached key if present.
  ///   2. Fetch the encrypted key from Firestore and decrypt with the user's
  ///      private RSA key.
  ///   3. If no key exists yet, generate one and distribute to all current
  ///      department members.
  ///
  /// Returns `null` if the user has no private key or an error occurs.
  static Future<Uint8List?> getOrCreate({
    required String organizationId,
    required String normalizedDepartmentId,
    required String currentUid,
  }) async {
    final cid = _cacheKey(organizationId, normalizedDepartmentId);
    if (_cache.containsKey(cid)) return _cache[cid];

    try {
      final privateKey = await KeyManagementService.getPrivateKey();
      if (privateKey == null) {
        debugPrint('[E2EE] No private key — cannot load conversation key');
        return null;
      }

      final keyDoc = await _keyRef(organizationId, normalizedDepartmentId)
          .doc(currentUid)
          .get();

      if (keyDoc.exists) {
        final encB64 = keyDoc.data()!['encryptedKey'] as String;
        final aesKey =
            RsaService.decrypt(base64Decode(encB64), privateKey);
        _cache[cid] = aesKey;
        debugPrint('[E2EE] Loaded conversation key for $cid');
        return aesKey;
      }

      // No key found — generate a fresh one and distribute to all dept members.
      debugPrint('[E2EE] No conversation key found, generating …');
      final aesKey = AesService.generateKey();
      await _distribute(
        organizationId: organizationId,
        normalizedDepartmentId: normalizedDepartmentId,
        aesKey: aesKey,
      );
      _cache[cid] = aesKey;
      return aesKey;
    } catch (e) {
      debugPrint('[E2EE] getOrCreate error: $e');
      return null;
    }
  }

  // ── Distribution ─────────────────────────────────────────────────────────────

  /// Distribute the cached conversation key to a member who joined after
  /// the key was first created (e.g. a new hire added to the department).
  ///
  /// Should be called by any online member from [ChatController] or the
  /// admin flow that adds a user to a department.
  static Future<void> distributeToNewMember({
    required String organizationId,
    required String normalizedDepartmentId,
    required String newMemberUid,
  }) async {
    final cid = _cacheKey(organizationId, normalizedDepartmentId);
    final aesKey = _cache[cid];
    if (aesKey == null) {
      debugPrint('[E2EE] No cached key to distribute to $newMemberUid');
      return;
    }
    await _encryptAndStore(
      organizationId: organizationId,
      normalizedDepartmentId: normalizedDepartmentId,
      aesKey: aesKey,
      memberUid: newMemberUid,
    );
    debugPrint('[E2EE] Distributed key to new member $newMemberUid');
  }

  // ── Cache management ─────────────────────────────────────────────────────────

  /// Evict the in-memory AES key for one conversation (e.g. after key rotation).
  static void evict(String organizationId, String normalizedDepartmentId) {
    _cache.remove(_cacheKey(organizationId, normalizedDepartmentId));
  }

  /// Clear the entire in-memory cache — call on logout.
  static void clearAll() => _cache.clear();

  // ── Private helpers ───────────────────────────────────────────────────────────

  static String _cacheKey(String orgId, String deptId) => '${orgId}_$deptId';

  static CollectionReference<Map<String, dynamic>> _keyRef(
    String orgId,
    String deptId,
  ) =>
      _firestore
          .collection('organizations')
          .doc(orgId)
          .collection('departments')
          .doc(deptId)
          .collection('conversationKeys');

  /// Generate + distribute an AES key to every employee in the department.
  static Future<void> _distribute({
    required String organizationId,
    required String normalizedDepartmentId,
    required Uint8List aesKey,
  }) async {
    // Query all employees in this department.
    final snap = await _firestore
        .collection('employees')
        .where('organizationId', isEqualTo: organizationId)
        .where('departmentId', isEqualTo: normalizedDepartmentId)
        .get();

    final memberUids = snap.docs.map((d) => d.id).toList();

    // Ensure at least the current user gets the key even if the query returns 0.
    final currentUid = KeyManagementService.currentUid;
    if (currentUid != null && !memberUids.contains(currentUid)) {
      memberUids.add(currentUid);
    }

    if (memberUids.isEmpty) return;

    // Distribute in parallel; skip members who have no public key yet.
    await Future.wait(
      memberUids.map((uid) => _encryptAndStore(
            organizationId: organizationId,
            normalizedDepartmentId: normalizedDepartmentId,
            aesKey: aesKey,
            memberUid: uid,
          )),
      eagerError: false,
    );

    debugPrint('[E2EE] Key distributed to ${memberUids.length} members');
  }

  /// Wrap [aesKey] with [memberUid]'s RSA public key and persist to Firestore.
  static Future<void> _encryptAndStore({
    required String organizationId,
    required String normalizedDepartmentId,
    required Uint8List aesKey,
    required String memberUid,
  }) async {
    final publicKey = await KeyManagementService.getPublicKey(memberUid);
    if (publicKey == null) {
      debugPrint('[E2EE] No public key for $memberUid — skipping');
      return;
    }

    final encryptedKey = RsaService.encrypt(aesKey, publicKey);
    await _keyRef(organizationId, normalizedDepartmentId).doc(memberUid).set({
      'encryptedKey': base64Encode(encryptedKey),
      'keyVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
