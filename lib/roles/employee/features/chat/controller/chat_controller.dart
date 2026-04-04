import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.organizationId,
    required this.departmentId,
    required this.departmentName,
    required this.displayId,
  }) {
    _listenForMessages();
  }

  final FirebaseService _firebase = FirebaseService.instance;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final String organizationId;
  final String departmentId;
  final String departmentName;
  final String displayId;

  List<ChatMessage> messages = [];
  bool isSending = false;
  String? errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  void _listenForMessages() {
    debugPrint('OrgId: $organizationId');
    debugPrint('DeptId: $departmentId');

    _subscription = _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('departments')
        .doc(_normalizedDepartmentId())
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            messages = snapshot.docs
                .map((doc) => ChatMessage.fromJson(doc.data(), id: doc.id))
                .toList();
            debugPrint('Messages count: ${messages.length}');
            notifyListeners();
            _scrollToBottom();
          },
          onError: (error) {
            errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _firebase.firestore
          .collection('organizations')
          .doc(organizationId)
          .collection('departments')
          .doc(_normalizedDepartmentId())
          .collection('messages')
          .add({
            'text': text,
            'senderId': displayId,
            'organizationId': organizationId,
            'departmentId': _normalizedDepartmentId(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  void _scrollToBottom() {
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _normalizedDepartmentId() {
    if (departmentId.trim().isNotEmpty) {
      return _sanitize(departmentId.trim());
    }
    if (departmentName.trim().isNotEmpty) {
      return _sanitize(departmentName.trim());
    }
    return 'general';
  }

  String _sanitize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.toLowerCase();
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
