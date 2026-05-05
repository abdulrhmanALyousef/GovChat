import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/activity_log_model.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/chat_message.dart';

class DeletedMessageItem {
  final String messageId;
  final String text;
  final String senderId;
  final String deletedBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final String departmentId;
  final String organizationId;

  DeletedMessageItem({
    required this.messageId,
    required this.text,
    required this.senderId,
    required this.deletedBy,
    this.deletedAt,
    this.createdAt,
    required this.departmentId,
    required this.organizationId,
  });

  factory DeletedMessageItem.fromMessage(ChatMessage msg) {
    return DeletedMessageItem(
      messageId: msg.id ?? '',
      text: msg.text,
      senderId: msg.senderId,
      deletedBy: msg.deletedBy ?? '',
      deletedAt: msg.deletedAt,
      createdAt: msg.createdAt,
      departmentId: msg.departmentId,
      organizationId: msg.organizationId,
    );
  }
}

class LogsController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  List<ActivityLogModel> activityLogs = [];
  List<DeletedMessageItem> deletedMessages = [];

  bool isLoadingLogs = true;
  bool isLoadingDeleted = true;
  String? logsError;
  String? deletedError;

  AdminModel? currentAdmin;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _logsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deletedSub;

  LogsController() {
    _init();
  }

  Future<void> _init() async {
    try {
      final user = _firebase.currentUser;
      if (user == null) {
        logsError = 'User not found';
        deletedError = 'User not found';
        isLoadingLogs = false;
        isLoadingDeleted = false;
        notifyListeners();
        return;
      }

      final doc = await _firebase.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        logsError = 'Admin data not found';
        deletedError = 'Admin data not found';
        isLoadingLogs = false;
        isLoadingDeleted = false;
        notifyListeners();
        return;
      }

      currentAdmin = AdminModel.fromJson(doc.data()!);
      final orgId = currentAdmin?.organizationId;

      if (orgId == null || orgId.isEmpty) {
        logsError = 'Organization not found for this admin account';
        deletedError = 'Organization not found for this admin account';
        isLoadingLogs = false;
        isLoadingDeleted = false;
        notifyListeners();
        return;
      }

      _listenToActivityLogs(orgId);
      _listenToDeletedMessages(orgId);
    } catch (e) {
      logsError = e.toString();
      deletedError = e.toString();
      isLoadingLogs = false;
      isLoadingDeleted = false;
      notifyListeners();
    }
  }

  void _listenToActivityLogs(String orgId) {
    _logsSub?.cancel();
    _logsSub = _firebase.firestore
        .collection('organizations')
        .doc(orgId)
        .collection('activityLogs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snap) {
            activityLogs = snap.docs
                .map((d) => ActivityLogModel.fromJson(d.data(), id: d.id))
                .toList();
            isLoadingLogs = false;
            notifyListeners();
          },
          onError: (e) {
            logsError = e.toString();
            isLoadingLogs = false;
            notifyListeners();
          },
        );
  }

  void _listenToDeletedMessages(String orgId) {
    _deletedSub?.cancel();
    _deletedSub = _firebase.firestore
        .collectionGroup('messages')
        .where('organizationId', isEqualTo: orgId)
        .where('isDeleted', isEqualTo: true)
        .orderBy('deletedAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snap) {
            deletedMessages = snap.docs
                .map((d) => DeletedMessageItem.fromMessage(
                    ChatMessage.fromJson(d.data(), id: d.id)))
                .toList();
            isLoadingDeleted = false;
            notifyListeners();
          },
          onError: (e) {
            deletedError = e.toString();
            isLoadingDeleted = false;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _logsSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }
}
