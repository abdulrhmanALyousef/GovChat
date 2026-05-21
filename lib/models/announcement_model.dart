import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String id;
  final String organizationId;
  final String title;
  final String content;
  final Map<String, dynamic> createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String priority; // 'normal' | 'high' | 'urgent'

  AnnouncementModel({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.content,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.isActive = true,
    this.priority = 'normal',
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isVisible => isActive && !isExpired;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json, String id) {
    return AnnouncementModel(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdBy: (json['createdBy'] as Map<String, dynamic>?) ?? {},
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      expiresAt: json['expiresAt'] is Timestamp
          ? (json['expiresAt'] as Timestamp).toDate()
          : null,
      isActive: json['isActive'] as bool? ?? true,
      priority: json['priority'] as String? ?? 'normal',
    );
  }
}
