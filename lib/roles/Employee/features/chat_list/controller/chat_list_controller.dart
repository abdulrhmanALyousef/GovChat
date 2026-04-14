import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/conversation_model.dart';
import '../../../../../models/employee_model.dart';

class ChatListController extends ChangeNotifier {
  ChatListController({required this.employee}) {
    _buildConversations();
  }

  final EmployeeModel employee;

  List<ConversationModel> conversations = [];
  bool isLoading = true;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _subscriptions = [];

  void _buildConversations() {
    final deptId = _normalizeDeptId();

    conversations = [
      ConversationModel(
        id: deptId,
        name: employee.department.isNotEmpty
            ? employee.department
            : 'Department Chat',
        type: 'department',
        organizationId: employee.organizationId,
        departmentId: deptId,
        department: employee.department,
      ),
    ];

    isLoading = false;
    notifyListeners();

    _listenToLastMessage(deptId, 0);
  }

  void _listenToLastMessage(String deptId, int index) {
    final sub = FirebaseService.instance.firestore
        .collection('organizations')
        .doc(employee.organizationId)
        .collection('departments')
        .doc(deptId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isEmpty) return;
            final data = snapshot.docs.first.data();
            final updated = conversations[index].copyWith(
              lastMessage: data['text'] as String?,
              lastSenderId: data['senderId'] as String?,
              lastMessageTime: ConversationModel.timestampToDateTime(
                data['createdAt'],
              ),
            );
            conversations = List<ConversationModel>.from(conversations)
              ..[index] = updated;
            notifyListeners();
          },
          onError: (_) {},
        );
    _subscriptions.add(sub);
  }

  String _normalizeDeptId() {
    final id = employee.departmentId.trim();
    if (id.isNotEmpty) return _sanitize(id);
    final name = employee.department.trim();
    if (name.isNotEmpty) return _sanitize(name);
    return 'general';
  }

  String _sanitize(String value) {
    return value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}