import 'dart:async';

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

  /// Sorted list shown in the UI: department chat first, then private chats
  /// ordered by most-recent message descending.
  List<ConversationModel> conversations = [];
  bool isLoading = true;

  // In-memory store keyed by conversation ID.
  final Map<String, ConversationModel> _convMap = {};

  // Firestore stream for private_chats collection.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _privateChatsSubscription;

  // Per-conversation last-message subscriptions, keyed by conversation ID.
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _lastMessageSubs = {};

  // Per-conversation profile subscriptions for private chats (other user's doc).
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _profileSubs = {};

  // Employee profile cache: uid → {name, avatarUrl, displayId}.
  // Populated by a live stream on all employees in the org.
  final Map<String, Map<String, String>> _profileCache = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _employeesSubscription;

  /// Resolve a sender's display name from their UID or displayId.
  String _resolveSenderName(String? senderUid, String? senderId) {
    // Try by UID first.
    if (senderUid != null && _profileCache.containsKey(senderUid)) {
      final name = _profileCache[senderUid]!['name'] ?? '';
      if (name.isNotEmpty) return name;
    }
    // Fall back to displayId match.
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
          for (final doc in snapshot.docs) {
            final data = doc.data();
            _profileCache[doc.id] = {
              'name': (data['name'] as String?) ?? '',
              'avatarUrl': (data['avatarUrl'] as String?) ?? '',
              'displayId': (data['displayId'] as String?) ?? '',
            };
          }
          // Re-resolve all lastSenderName values with fresh data.
          _refreshLastSenderNames();
          notifyListeners();
        }, onError: (_) {});
  }

  /// Walk all conversations and re-resolve lastSenderName, plus refresh
  /// private chat names and avatars from the profile cache.
  void _refreshLastSenderNames() {
    for (final entry in _convMap.entries) {
      var conv = entry.value;

      // Re-resolve last sender name.
      if (conv.lastSenderId != null) {
        final resolved = _resolveSenderName(null, conv.lastSenderId);
        if (resolved != conv.lastSenderName) {
          conv = conv.copyWith(lastSenderName: resolved);
          _convMap[entry.key] = conv;
        }
      }

      // Refresh private chat name and avatar from the profile cache.
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
          // Structural chat metadata changes are rare; last-message stream
          // handles the preview updates independently.
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

    // Prefer fresh data from profile cache over stale participantNames.
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

  /// Live-stream the other participant's employee doc so that name and avatar
  /// stay up to date when they edit their profile.
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
          final data = doc.data();
          if (data == null) return;
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

    _lastMessageSubs[convId] = FirebaseService.instance.firestore
        .collection(messagesPath)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          final existing = _convMap[convId];
          if (existing == null) return;
          if (snapshot.docs.isEmpty) return;

          final data = snapshot.docs.first.data();
          final isEncrypted = data['isEncrypted'] as bool? ?? false;
          final rawText = data['text'] as String?;
          final messageType = data['messageType'] as String? ?? 'text';

          // For media messages, the preview is handled by the UI
          // based on lastMessageType — no need to decrypt.
          String? displayText;
          if (messageType == 'text') {
            if (isEncrypted) {
              final msgId = snapshot.docs.first.id;
              displayText = await _decryptLastMessage(data, existing, msgId);
            }
          }

          final senderId = data['senderId'] as String?;
          final senderUid = data['senderUid'] as String?;
          final senderName = _resolveSenderName(senderUid, senderId);

          _convMap[convId] = existing.copyWith(
            lastMessage:
                displayText ??
                (messageType != 'text'
                    ? ''
                    : isEncrypted
                    ? '[Encrypted message]'
                    : rawText),
            lastMessageType: messageType,
            lastSenderId: senderId,
            lastSenderName: senderName,
            lastMessageTime: ConversationModel.timestampToDateTime(
              data['createdAt'],
            ),
          );
          _rebuildList();
          notifyListeners();
        }, onError: (_) {});
  }

  /// Try to decrypt the last message preview.
  /// Returns null if decryption fails (caller falls back to placeholder).
  Future<String?> _decryptLastMessage(
    Map<String, dynamic> data,
    ConversationModel conv,
    String messageId,
  ) async {
    final encryptedText = data['encryptedText'] as String?;
    final iv = data['iv'] as String?;
    if (encryptedText == null || iv == null) return null;

    try {
      // Derive the conversation path from the messages path.
      final convPath = conv.messagesCollectionPath.replaceAll('/messages', '');

      // Try loading from secure storage first (fast path).
      var key = await E2eeKeyStore.getConversationKey(convPath);

      // If not cached, derive/fetch the key.
      if (key == null) {
        final uid = E2eeManager.currentUid;
        if (uid == null) return null;

        key = await E2eeManager.getConversationKey(
          conversationPath: convPath,
          currentUid: uid,
          memberUids: const [],
          isPrivateChat: conv.type == 'private',
        );
      }

      if (key == null) return null;

      final decrypted = await E2eeManager.decryptMessage(
        EncryptedPayload(ciphertext: encryptedText, nonce: iv),
        key,
      );

      // Store the FULL plaintext in the shared cache so the chat screen
      // can display it immediately without re-decrypting.
      E2eeManager.cacheDecryptedText(messageId, decrypted);

      // Truncate for preview.
      if (decrypted.length > 80) {
        return '${decrypted.substring(0, 80)}…';
      }
      return decrypted;
    } catch (e) {
      debugPrint('[E2EE] last message decrypt failed for ${conv.id}: $e');
      return null;
    }
  }

  // ─── List ordering ────────────────────────────────────────────────────────

  /// All conversations sorted by most-recent message, newest first.
  /// Conversations with no messages yet sink to the bottom.
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
