import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, read }

class ChatMessage {
  final String? id;
  final String text;
  final String senderId;
  final String organizationId;
  final String departmentId;
  final DateTime? createdAt;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  /// 'admin' when sent by an admin user; null/empty otherwise.
  final String? senderRole;

  /// DisplayIds of participants who have opened this message.
  final List<String> readBy;

  ChatMessage({
    this.id,
    required this.text,
    required this.senderId,
    required this.organizationId,
    required this.departmentId,
    this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.senderRole,
    this.readBy = const [],
  });

  /// Returns the delivery/read status from the perspective of [myDisplayId].
  /// Only meaningful for messages sent by [myDisplayId].
  MessageStatus statusFor(String myDisplayId) {
    if (readBy.any((id) => id != myDisplayId)) return MessageStatus.read;
    if (createdAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? id}) {
    return ChatMessage(
      id: id,
      text: json['text'] ?? '',
      senderId: json['senderId'] ?? '',
      organizationId: json['organizationId'] ?? '',
      departmentId: json['departmentId'] ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] is Timestamp
          ? (json['editedAt'] as Timestamp).toDate()
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] is Timestamp
          ? (json['deletedAt'] as Timestamp).toDate()
          : null,
      deletedBy: json['deletedBy'] as String?,
      senderRole: json['senderRole'] as String?,
      readBy: List<String>.from(json['readBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderId': senderId,
      'organizationId': organizationId,
      'departmentId': departmentId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
