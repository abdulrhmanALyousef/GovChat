import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectGroupModel {
  final String? id;
  final String organizationId;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProjectGroupModel({
    this.id,
    required this.organizationId,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.createdAt,
    this.updatedAt,
  });

  String get messagesPath => 'projectGroups/${id!}/messages';

  factory ProjectGroupModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ProjectGroupModel(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      memberIds: List<String>.from(json['memberIds'] as List? ?? []),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'name': name,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
