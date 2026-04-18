import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
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

  // ─── Init ────────────────────────────────────────────────────────────────

  void _init() {
    _addOrganizationChat();
    _addDepartmentChat();
    _listenToPrivateChats();
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
      name: employee.department.isNotEmpty ? employee.department : 'Department Chat',
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
        .listen(
          _handlePrivateChatSnapshot,
          onError: (_) {},
        );
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
    final participants =
        List<String>.from((data['participants'] as List?) ?? []);
    final otherId =
        participants.firstWhere((id) => id != myId, orElse: () => '');

    final displayIds = _toStringMap(data['participantDisplayIds']);
    final otherDisplayId = displayIds[otherId]?.trim().isNotEmpty == true
        ? displayIds[otherId]!
        : 'Unknown';

    final conv = ConversationModel(
      id: chatId,
      name: otherDisplayId,
      type: 'private',
      organizationId: employee.organizationId,
      departmentId: '',
      department: '',
    );

    _convMap[chatId] = conv;
    _subscribeToLastMessage(chatId, conv.messagesCollectionPath);
  }

  void _onPrivateChatRemoved(String chatId) {
    _lastMessageSubs[chatId]?.cancel();
    _lastMessageSubs.remove(chatId);
    _convMap.remove(chatId);
  }

  // ─── Last-message subscriptions ──────────────────────────────────────────

  void _subscribeToLastMessage(String convId, String messagesPath) {
    // Cancel any existing subscription for this conversation before (re)subscribing.
    _lastMessageSubs[convId]?.cancel();

    _lastMessageSubs[convId] = FirebaseService.instance.firestore
        .collection(messagesPath)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            final existing = _convMap[convId];
            if (existing == null) return;
            if (snapshot.docs.isEmpty) return;

            final data = snapshot.docs.first.data();
            _convMap[convId] = existing.copyWith(
              lastMessage: data['text'] as String?,
              lastSenderId: data['senderId'] as String?,
              lastMessageTime: ConversationModel.timestampToDateTime(
                data['createdAt'],
              ),
            );
            _rebuildList();
            notifyListeners();
          },
          onError: (_) {},
        );
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
    for (final sub in _lastMessageSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
