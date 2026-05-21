import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/encryption/e2ee_crypto.dart';
import '../../../../../core/services/encryption/e2ee_key_store.dart';
import '../../../../../core/services/encryption/e2ee_manager.dart';
import '../../../../../models/conversation_model.dart';
import '../../../../../models/employee_model.dart';

class ChatListController extends ChangeNotifier {
  ChatListController({required this.employee}) {
    _init();
  }

  final EmployeeModel employee;

  List<ConversationModel> conversations = [];
  bool isLoading = true;

  final Map<String, ConversationModel> _convMap = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _privateChatsSubscription;

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _lastMessageSubs = {};

  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _profileSubs = {};

  final Map<String, Map<String, String>> _profileCache = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _employeesSubscription;

  String _resolveSenderName(String? senderUid, String? senderId) {
    if (senderUid != null && _profileCache.containsKey(senderUid)) {
      final name = _profileCache[senderUid]!['name'] ?? '';
      if (name.isNotEmpty) return name;
    }
    if (senderId != null) {
      for (final p in _profileCache.values) {
        if (p['displayId'] == senderId) {
          final name = p['name'] ?? '';
          if (name.isNotEmpty) return name;
        }
      }
    }
    return senderId ?? '';
  }

  // ─── Init ────────────────────────────────────────────────────────────────

  void _init() {
    _listenToEmployeeProfiles();
    _addOrganizationChat();
    _addDepartmentChat();
    _listenToPrivateChats();
    _listenToProjectGroups();
  }

  void _listenToEmployeeProfiles() {
    _employeesSubscription = FirebaseService.instance.firestore
        .collection('employees')
        .where('organizationId', isEqualTo: employee.organizationId)
        .snapshots()
        .listen((snapshot) {
          final validUids = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            validUids.add(doc.id);
            _profileCache[doc.id] = {
              'name': (data['name'] as String?) ?? '',
              'avatarUrl': (data['avatarUrl'] as String?) ?? '',
              'displayId': (data['displayId'] as String?) ?? '',
            };
          }

          // Remove private chats whose other user is no longer a valid employee.
          final staleIds = <String>[];
          for (final entry in _convMap.entries) {
            final conv = entry.value;
            if (conv.type == 'private' &&
                conv.otherUid.isNotEmpty &&
                !validUids.contains(conv.otherUid)) {
              staleIds.add(entry.key);
            }
          }
          for (final id in staleIds) {
            debugPrint('[INBOX] pruning stale private chat $id');
            _onPrivateChatRemoved(id);
          }

          _refreshLastSenderNames();
          notifyListeners();
        }, onError: (_) {});
  }

  void _refreshLastSenderNames() {
    for (final entry in _convMap.entries) {
      var conv = entry.value;

      if (conv.lastSenderId != null) {
        final resolved = _resolveSenderName(null, conv.lastSenderId);
        if (resolved != conv.lastSenderName) {
          conv = conv.copyWith(lastSenderName: resolved);
          _convMap[entry.key] = conv;
        }
      }

      if (conv.type == 'private' && conv.otherUid.isNotEmpty) {
        final profile = _profileCache[conv.otherUid];
        if (profile != null) {
          final name = profile['name'] ?? '';
          final avatarUrl = profile['avatarUrl'] ?? '';
          if (name != conv.name || avatarUrl != conv.avatarUrl) {
            _convMap[entry.key] = conv.copyWith(
              name: name.isNotEmpty ? name : null,
              avatarUrl: avatarUrl,
            );
          }
        }
      }
    }
    _rebuildList();
  }

  // ─── Organization-wide general chat ──────────────────────────────────────

  void _addOrganizationChat() {
    const convId = 'org_general';

    final conv = ConversationModel(
      id: convId,
      name: employee.organizationName.isNotEmpty
          ? employee.organizationName
          : 'General Chat',
      type: 'organization',
      organizationId: employee.organizationId,
      departmentId: '',
      department: '',
    );

    _convMap[convId] = conv;
    _subscribeToLastMessage(convId, conv.messagesCollectionPath);
  }

  // ─── Department chat ──────────────────────────────────────────────────────

  void _addDepartmentChat() {
    final deptId = _normalizeDeptId();
    final convId = 'dept_$deptId';

    final conv = ConversationModel(
      id: convId,
      name: employee.department.isNotEmpty
          ? employee.department
          : 'Department Chat',
      type: 'department',
      organizationId: employee.organizationId,
      departmentId: deptId,
      department: employee.department,
    );

    _convMap[convId] = conv;
    _rebuildList();
    isLoading = false;
    notifyListeners();

    _subscribeToLastMessage(convId, conv.messagesCollectionPath);
  }

  // ─── Private chats ────────────────────────────────────────────────────────

  void _listenToPrivateChats() {
    _privateChatsSubscription = FirebaseService.instance.firestore
        .collection('organizations')
        .doc(employee.organizationId)
        .collection('private_chats')
        .where('participants', arrayContains: employee.id ?? '')
        .snapshots()
        .listen(_handlePrivateChatSnapshot, onError: (_) {});
  }

  void _handlePrivateChatSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
          _onPrivateChatAdded(change.doc.id, change.doc.data()!);
          break;
        case DocumentChangeType.removed:
          _onPrivateChatRemoved(change.doc.id);
          break;
        case DocumentChangeType.modified:
          break;
      }
    }
    _rebuildList();
    notifyListeners();
  }

  void _onPrivateChatAdded(String chatId, Map<String, dynamic> data) {
    if (_convMap.containsKey(chatId)) return;

    final myId = employee.id ?? '';
    final participants = List<String>.from(
      (data['participants'] as List?) ?? [],
    );
    final otherId = participants.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    if (otherId.isEmpty || otherId == myId) return;

    if (!_profileCache.containsKey(otherId)) {
      _verifyAndAddPrivateChat(chatId, data, otherId);
      return;
    }

    _addVerifiedPrivateChat(chatId, data, otherId);
  }

  void _verifyAndAddPrivateChat(
    String chatId,
    Map<String, dynamic> data,
    String otherId,
  ) async {
    try {
      final doc = await FirebaseService.instance.firestore
          .collection('employees')
          .doc(otherId)
          .get();

      if (!doc.exists) return;

      final empData = doc.data()!;
      final orgId = empData['organizationId'] as String? ?? '';
      if (orgId != employee.organizationId) return;

      _profileCache[otherId] = {
        'name': (empData['name'] as String?) ?? '',
        'avatarUrl': (empData['avatarUrl'] as String?) ?? '',
        'displayId': (empData['displayId'] as String?) ?? '',
      };

      _addVerifiedPrivateChat(chatId, data, otherId);
      _rebuildList();
      notifyListeners();
    } catch (_) {}
  }

  void _addVerifiedPrivateChat(
    String chatId,
    Map<String, dynamic> data,
    String otherId,
  ) {
    if (_convMap.containsKey(chatId)) return;

    final cached = _profileCache[otherId];
    final cachedName = cached?['name'] ?? '';
    final cachedAvatar = cached?['avatarUrl'] ?? '';

    String otherName;
    if (cachedName.isNotEmpty) {
      otherName = cachedName;
    } else {
      final names = _toStringMap(data['participantNames']);
      otherName = names[otherId]?.trim().isNotEmpty == true
          ? names[otherId]!
          : 'Unknown';
    }

    final conv = ConversationModel(
      id: chatId,
      name: otherName,
      type: 'private',
      organizationId: employee.organizationId,
      departmentId: '',
      department: '',
      otherUid: otherId,
      avatarUrl: cachedAvatar,
    );

    _convMap[chatId] = conv;
    _subscribeToLastMessage(chatId, conv.messagesCollectionPath);
    _subscribeToOtherProfile(chatId, otherId);
  }

  void _subscribeToOtherProfile(String chatId, String otherId) {
    if (otherId.isEmpty) return;
    _profileSubs[chatId]?.cancel();
    _profileSubs[chatId] = FirebaseService.instance.firestore
        .collection('employees')
        .doc(otherId)
        .snapshots()
        .listen((doc) {
          final existing = _convMap[chatId];
          if (existing == null) return;

          if (!doc.exists) {
            _onPrivateChatRemoved(chatId);
            _rebuildList();
            notifyListeners();
            return;
          }

          final data = doc.data();
          if (data == null) return;

          final orgId = data['organizationId'] as String? ?? '';
          if (orgId != employee.organizationId) {
            _onPrivateChatRemoved(chatId);
            _rebuildList();
            notifyListeners();
            return;
          }

          final name = (data['name'] as String?) ?? '';
          final avatarUrl = (data['avatarUrl'] as String?) ?? '';
          _convMap[chatId] = existing.copyWith(
            name: name.isNotEmpty ? name : null,
            avatarUrl: avatarUrl,
          );
          _rebuildList();
          notifyListeners();
        }, onError: (_) {});
  }

  void _onPrivateChatRemoved(String chatId) {
    _lastMessageSubs[chatId]?.cancel();
    _lastMessageSubs.remove(chatId);
    _profileSubs[chatId]?.cancel();
    _profileSubs.remove(chatId);
    _convMap.remove(chatId);
  }

  // ─── Project groups ──────────────────────────────────────────────────────

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsSub;

  void _listenToProjectGroups() {
    final uid = employee.id ?? '';
    if (uid.isEmpty) return;

    _groupsSub = FirebaseService.instance.firestore
        .collection('projectGroups')
        .where('organizationId', isEqualTo: employee.organizationId)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen(_handleGroupSnapshot, onError: (_) {});
  }

  void _handleGroupSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
          _onGroupAdded(change.doc.id, change.doc.data()!);
          break;
        case DocumentChangeType.removed:
          _onGroupRemoved(change.doc.id);
          break;
        case DocumentChangeType.modified:
          break;
      }
    }
    _rebuildList();
    notifyListeners();
  }

  void _onGroupAdded(String groupId, Map<String, dynamic> data) {
    final convId = 'group_$groupId';
    if (_convMap.containsKey(convId)) return;

    final conv = ConversationModel(
      id: groupId,
      name: (data['name'] as String?) ?? 'Group',
      type: 'group',
      organizationId: employee.organizationId,
      departmentId: '',
      department: '',
    );

    _convMap[convId] = conv;
    _subscribeToLastMessage(convId, conv.messagesCollectionPath);
  }

  void _onGroupRemoved(String groupId) {
    final convId = 'group_$groupId';
    _lastMessageSubs[convId]?.cancel();
    _lastMessageSubs.remove(convId);
    _convMap.remove(convId);
  }

  // ─── Last-message subscriptions ──────────────────────────────────────────

  void _subscribeToLastMessage(String convId, String messagesPath) {
    _lastMessageSubs[convId]?.cancel();

    // Fetch a small window so we can fall back to an older decryptable message
    // if the newest one can't be decrypted yet.
    _lastMessageSubs[convId] = FirebaseService.instance.firestore
        .collection(messagesPath)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) async {
          final existing = _convMap[convId];
          if (existing == null) return;
          if (snapshot.docs.isEmpty) return;

          // Always use the newest message for timestamp and metadata.
          final newest = snapshot.docs.first.data();
          final newestType = newest['messageType'] as String? ?? 'text';
          final timestamp = ConversationModel.timestampToDateTime(
            newest['createdAt'],
          );
          final senderId = newest['senderId'] as String?;
          final senderUid = newest['senderUid'] as String?;
          final senderName = _resolveSenderName(senderUid, senderId);

          // Walk through recent messages to find the best preview text.
          String? preview;
          String? previewType;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final msgType = data['messageType'] as String? ?? 'text';
            final isEncrypted = data['isEncrypted'] as bool? ?? false;
            final isDeleted = data['isDeleted'] as bool? ?? false;
            if (isDeleted) continue;

            // Media message: use type label as preview.
            if (msgType != 'text') {
              preview = '';
              previewType = msgType;
              break;
            }

            // Plain text (not encrypted).
            if (!isEncrypted) {
              final raw = data['text'] as String? ?? '';
              if (raw.isNotEmpty) {
                preview = _truncate(raw);
                previewType = 'text';
                break;
              }
              continue;
            }

            // Encrypted text: try to decrypt.
            final decrypted = await _tryDecrypt(data, existing, doc.id);
            if (decrypted != null) {
              preview = decrypted;
              previewType = 'text';
              break;
            }
          }

          final fresh = _convMap[convId];
          if (fresh == null) return;
          _convMap[convId] = fresh.copyWith(
            lastMessage: preview ?? fresh.lastMessage,
            lastMessageType: previewType ?? newestType,
            lastSenderId: senderId,
            lastSenderName: senderName,
            lastMessageTime: timestamp,
          );
          _rebuildList();
          notifyListeners();
        }, onError: (_) {});
  }

  /// Attempt to decrypt a message preview. Returns plaintext or null.
  /// Lightweight: uses cached keys or single Firestore reads. Never hangs.
  Future<String?> _tryDecrypt(
    Map<String, dynamic> data,
    ConversationModel conv,
    String messageId,
  ) async {
    final encryptedText = data['encryptedText'] as String?;
    final iv = data['iv'] as String?;
    if (encryptedText == null || iv == null) return null;

    try {
      // 1. Already decrypted elsewhere (e.g. chat screen)?
      final cached = E2eeManager.getCachedDecryptedText(messageId);
      if (cached != null) return _truncate(cached);

      final convPath = conv.messagesCollectionPath.replaceAll('/messages', '');

      // 2. Get conversation key: memory → storage → lightweight derivation.
      var key = E2eeKeyStore.getConversationKeyCached(convPath);
      key ??= await E2eeKeyStore.getConversationKey(convPath);
      key ??= await _lightweightKeyLookup(conv, convPath);
      if (key == null) return null;

      // 3. Decrypt.
      final decrypted = await E2eeCrypto.decrypt(
        EncryptedPayload(ciphertext: encryptedText, nonce: iv),
        key,
      ).timeout(const Duration(seconds: 5));

      E2eeManager.cacheDecryptedText(messageId, decrypted);
      return _truncate(decrypted);
    } catch (e) {
      debugPrint('[INBOX] decrypt failed for ${conv.id}: $e');
      return null;
    }
  }

  /// Get a conversation key without entering the heavy group-key creation flow.
  Future<Uint8List?> _lightweightKeyLookup(
    ConversationModel conv,
    String convPath,
  ) async {
    final myPrivateKey = await E2eeKeyStore.getPrivateKey();
    if (myPrivateKey == null) return null;

    if (conv.type == 'private' && conv.otherUid.isNotEmpty) {
      final theirPub = await _fetchPublicKey(conv.otherUid);
      if (theirPub == null) return null;

      final aesKey = await E2eeCrypto.deriveSharedKey(
        myPrivateKeyB64: myPrivateKey,
        theirPublicKeyB64: theirPub,
        info: 'govchat:private:$convPath',
      );
      await E2eeKeyStore.saveConversationKey(convPath, aesKey);
      return aesKey;
    }

    // Group / dept / org: read own wrapped-key doc.
    final uid = E2eeManager.currentUid;
    if (uid == null) return null;

    final doc = await FirebaseService.instance.firestore
        .doc('$convPath/groupKey/$uid')
        .get();
    if (!doc.exists) return null;

    final d = doc.data()!;
    final wrappedKey = d['wrappedKey'] as String?;
    final nonce = d['nonce'] as String?;
    final creatorPub = d['creatorPublicKey'] as String?;
    if (wrappedKey == null || nonce == null || creatorPub == null) return null;

    final groupKey = await E2eeCrypto.unwrapGroupKey(
      wrappedKey: EncryptedPayload(ciphertext: wrappedKey, nonce: nonce),
      myPrivateKeyB64: myPrivateKey,
      senderPublicKeyB64: creatorPub,
      info: 'govchat:group:$convPath',
    );
    await E2eeKeyStore.saveConversationKey(convPath, groupKey);
    return groupKey;
  }

  Future<String?> _fetchPublicKey(String uid) async {
    var doc = await FirebaseService.instance.firestore
        .collection('employees')
        .doc(uid)
        .get();
    var pubKey = doc.data()?['e2eePublicKey'] as String?;
    if (pubKey != null && pubKey.isNotEmpty) return pubKey;

    doc = await FirebaseService.instance.firestore
        .collection('users')
        .doc(uid)
        .get();
    pubKey = doc.data()?['e2eePublicKey'] as String?;
    return (pubKey != null && pubKey.isNotEmpty) ? pubKey : null;
  }

  static String _truncate(String text) {
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }

  // ─── List ordering ────────────────────────────────────────────────────────

  void _rebuildList() {
    conversations = _convMap.values.toList()
      ..sort((a, b) {
        final aTime =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _normalizeDeptId() {
    final id = employee.departmentId.trim();
    if (id.isNotEmpty) return _sanitize(id);
    final name = employee.department.trim();
    if (name.isNotEmpty) return _sanitize(name);
    return 'general';
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();

  Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _privateChatsSubscription?.cancel();
    _employeesSubscription?.cancel();
    _groupsSub?.cancel();
    for (final sub in _lastMessageSubs.values) {
      sub.cancel();
    }
    for (final sub in _profileSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
