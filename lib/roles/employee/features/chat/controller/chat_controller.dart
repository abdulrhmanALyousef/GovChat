import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  // Exposed so _InputBar can attach it to the TextField for auto-focus.
  ChatController({
    required this.organizationId,
    required this.departmentId,
    required this.departmentName,
    required this.displayId,
    this.messagesPath,
  }) {
    _listenForMessages();
    _listenToTyping();
  }

  final FirebaseService _firebase = FirebaseService.instance;
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocusNode = FocusNode();

  final String organizationId;
  final String departmentId;
  final String departmentName;
  final String displayId;

  /// When set, overrides the default department-based Firestore path.
  /// Must be a full slash-separated collection path, e.g.:
  /// "organizations/orgId/private_chats/chatId/messages"
  final String? messagesPath;

  List<ChatMessage> messages = [];
  bool isSending = false;
  String? errorMessage;

  /// Non-null while the user is editing an existing message.
  ChatMessage? editingMessage;
  bool get isEditing => editingMessage != null;

  /// DisplayIds of other participants currently typing.
  List<String> typingDisplayIds = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _typingSubscription;

  Timer? _typingDebounceTimer;
  Timer? _typingClearTimer;

  /// True once we have written our own typing status to Firestore, so we know
  /// it is safe (and necessary) to delete it on clear.
  bool _isTypingSet = false;

  void _listenForMessages() {
    debugPrint('OrgId: $organizationId');
    debugPrint('DeptId: $departmentId');

    _subscription = _messagesCollection()
        .orderBy('createdAt')
        .snapshots()
        .listen(
          (snapshot) {
            messages = snapshot.docs
                .map((doc) => ChatMessage.fromJson(doc.data(), id: doc.id))
                .toList();
            debugPrint('Messages count: ${messages.length}');
            _markMessagesAsRead(snapshot.docs).ignore();
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

    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _setTyping(false).ignore();

    isSending = true;
    errorMessage = null;
    notifyListeners();

    try {
      final ref = await _messagesCollection().add({
        'text': text,
        'senderId': displayId,
        'organizationId': organizationId,
        'departmentId': _normalizedDepartmentId(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'message_sent',
        descriptionKey: 'logMessageSent',
        performedByUserId: _firebase.currentUser?.uid ?? displayId,
        performedByRole: 'employee',
        performedByName: displayId,
        targetId: ref.id,
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
          'messagePreview': text.length > 50 ? text.substring(0, 50) : text,
        },
      );

      messageController.clear();
      _scrollToBottom();
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  // ─── Delete helper ───────────────────────────────────────────────────────

  Future<void> deleteMessage(ChatMessage message) async {
    if (message.id == null) return;
    try {
      await _messagesCollection().doc(message.id!).delete();
      LoggingService.instance.log(
        organizationId: organizationId,
        actionType: 'message_deleted',
        descriptionKey: 'logMessageDeleted',
        performedByUserId: _firebase.currentUser?.uid ?? displayId,
        performedByRole: 'employee',
        performedByName: displayId,
        targetId: message.id,
        metadata: {
          'chatType': _detectChatType(),
          'departmentId': _normalizedDepartmentId(),
        },
      );
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  String _detectChatType() {
    if (messagesPath == null || messagesPath!.isEmpty) return 'department';
    if (messagesPath!.contains('private_chats')) return 'private';
    if (messagesPath!.contains('org_chats')) return 'organization';
    return 'department';
  }

  // ─── Edit helpers ────────────────────────────────────────────────────────

  void startEditing(ChatMessage message) {
    editingMessage = message;
    messageController.text = message.text;
    messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: message.text.length),
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inputFocusNode.requestFocus();
    });
  }

  void cancelEditing() {
    editingMessage = null;
    messageController.clear();
    notifyListeners();
  }

  Future<void> confirmEdit() async {
    final msg = editingMessage;
    if (msg == null || msg.id == null) return;

    final newText = messageController.text.trim();
    if (newText.isEmpty) return;
    if (newText == msg.text) {
      cancelEditing();
      return;
    }

    isSending = true;
    notifyListeners();

    try {
      await _messagesCollection().doc(msg.id!).update({
        'text': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      cancelEditing();
    } catch (e) {
      errorMessage = e.toString();
    }

    isSending = false;
    notifyListeners();
  }

  // ─── Typing indicators ───────────────────────────────────────────────────

  /// Called by the TextField's onChanged; debounces Firestore writes and
  /// auto-clears the status after 4 s of inactivity.
  void onTextChanged(String text) {
    debugPrint('[Typing] onTextChanged: "${text.length} chars"');
    if (text.isNotEmpty) {
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(
        const Duration(milliseconds: 300),
        () => _setTyping(true).ignore(),
      );
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(
        const Duration(seconds: 4),
        () => _setTyping(false).ignore(),
      );
    } else {
      _typingDebounceTimer?.cancel();
      _typingClearTimer?.cancel();
      _setTyping(false).ignore();
    }
  }

  void _listenToTyping() {
    debugPrint('[Typing] _listenToTyping() started for doc: ${_chatDocRef().path}');
    _typingSubscription = _chatDocRef().snapshots().listen(
      (snap) {
        if (!snap.exists) {
          debugPrint('[Typing] chat doc does not exist');
          if (typingDisplayIds.isNotEmpty) {
            typingDisplayIds = [];
            notifyListeners();
          }
          return;
        }
        final data = snap.data() ?? {};
        final raw = Map<String, dynamic>.from(data['typing'] as Map? ?? {});
        debugPrint('[Typing] raw typing map: $raw');
        final now = DateTime.now();
        typingDisplayIds = raw.entries
            .where((e) => e.key != displayId)
            .where((e) {
              final ts = e.value;
              if (ts is Timestamp) {
                return now.difference(ts.toDate()) <
                    const Duration(seconds: 10);
              }
              return false;
            })
            .map((e) => e.key)
            .toList();
        debugPrint('[Typing] typingDisplayIds: $typingDisplayIds');
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[Typing] stream error: $e');
      },
    );
  }

  Future<void> _setTyping(bool isTyping) async {
    try {
      if (isTyping) {
        debugPrint('[Typing] setting typing=true for $displayId');
        await _chatDocRef().set(
          {
            'typing': {displayId: FieldValue.serverTimestamp()},
          },
          SetOptions(mergeFields: [FieldPath(['typing', displayId])]),
        );
        _isTypingSet = true;
      } else if (_isTypingSet) {
        debugPrint('[Typing] clearing typing for $displayId');
        await _chatDocRef()
            .update({'typing.$displayId': FieldValue.delete()});
        _isTypingSet = false;
      }
    } catch (e) {
      debugPrint('[Typing] _setTyping error: $e');
    }
  }

  /// Returns the document that owns this chat (parent of the messages
  /// collection). Used to read/write the `typing` map.
  DocumentReference<Map<String, dynamic>> _chatDocRef() {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      // e.g. "organizations/orgId/private_chats/chatId/messages"
      //  → drop the last path segment to get the chat document.
      final segments = messagesPath!.split('/');
      final docPath = segments.sublist(0, segments.length - 1).join('/');
      return _firebase.firestore.doc(docPath);
    }
    return _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('departments')
        .doc(_normalizedDepartmentId());
  }

  // ─── Read receipts ───────────────────────────────────────────────────────

  /// Batch-marks every message sent by someone else as read by [displayId].
  /// Called fire-and-forget from the stream listener; errors are swallowed so
  /// they never surface to the UI.
  Future<void> _markMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where((doc) {
      final data = doc.data();
      final senderId = data['senderId'] as String? ?? '';
      if (senderId == displayId) return false;
      final readBy = List<String>.from(data['readBy'] as List? ?? []);
      return !readBy.contains(displayId);
    }).toList();

    if (unread.isEmpty) return;

    final batch = _firebase.firestore.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([displayId]),
      });
    }
    try {
      await batch.commit();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _messagesCollection() {
    if (messagesPath != null && messagesPath!.isNotEmpty) {
      return _firebase.firestore.collection(messagesPath!);
    }
    return _firebase.firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('departments')
        .doc(_normalizedDepartmentId())
        .collection('messages');
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
    _typingDebounceTimer?.cancel();
    _typingClearTimer?.cancel();
    _setTyping(false).ignore();
    _typingSubscription?.cancel();
    messageController.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    _subscription?.cancel();
    super.dispose();
  }
}
