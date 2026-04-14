import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String name;
  final String type; // 'department', 'private'
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageTime;
  final String organizationId;
  final String departmentId;
  final String department;

  const ConversationModel({
    required this.id,
    required this.name,
    required this.type,
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageTime,
    required this.organizationId,
    required this.departmentId,
    required this.department,
  });

  ConversationModel copyWith({
    String? lastMessage,
    String? lastSenderId,
    DateTime? lastMessageTime,
  }) {
    return ConversationModel(
      id: id,
      name: name,
      type: type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      organizationId: organizationId,
      departmentId: departmentId,
      department: department,
    );
  }

  /// Full Firestore collection path for messages in this conversation.
  String get messagesCollectionPath {
    if (type == 'private') {
      return 'organizations/$organizationId/private_chats/$id/messages';
    }
    return 'organizations/$organizationId/departments/$departmentId/messages';
  }

  static DateTime? timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}