import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String name;
  final String type; // 'organization', 'department', 'private'
  final String? lastMessage;
  final String? lastSenderId;
  final String? lastSenderName;
  final DateTime? lastMessageTime;
  final String organizationId;
  final String departmentId;
  final String department;
  final String avatarUrl;

  /// For private chats: the UID of the other participant.
  final String otherUid;

  const ConversationModel({
    required this.id,
    required this.name,
    required this.type,
    this.lastMessage,
    this.lastSenderId,
    this.lastSenderName,
    this.lastMessageTime,
    required this.organizationId,
    required this.departmentId,
    required this.department,
    this.avatarUrl = '',
    this.otherUid = '',
  });

  ConversationModel copyWith({
    String? name,
    String? lastMessage,
    String? lastSenderId,
    String? lastSenderName,
    DateTime? lastMessageTime,
    String? avatarUrl,
  }) {
    return ConversationModel(
      id: id,
      name: name ?? this.name,
      type: type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      organizationId: organizationId,
      departmentId: departmentId,
      department: department,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      otherUid: otherUid,
    );
  }

  /// Full Firestore collection path for messages in this conversation.
  String get messagesCollectionPath {
    if (type == 'private') {
      return 'organizations/$organizationId/private_chats/$id/messages';
    }
    if (type == 'organization') {
      return 'organizations/$organizationId/org_chats/general/messages';
    }
    return 'organizations/$organizationId/departments/$departmentId/messages';
  }

  static DateTime? timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}