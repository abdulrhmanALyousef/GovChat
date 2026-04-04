import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String text;
  final String senderId;
  final String organizationId;
  final String departmentId;
  final DateTime? createdAt;

  ChatMessage({
    this.id,
    required this.text,
    required this.senderId,
    required this.organizationId,
    required this.departmentId,
    this.createdAt,
  });

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
