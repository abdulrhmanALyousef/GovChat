import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;
  final String action;
  final String actorId;
  final String actorEmail;
  final String actorRole;
  final String? organizationId;
  final String? organizationName;
  final String? targetId;
  final String? targetEmail;
  final String? description;
  final String? descriptionKey;
  final Map<String, dynamic>? metadata;
  final DateTime? timestamp;

  const ActivityLogModel({
    this.id,
    required this.action,
    required this.actorId,
    required this.actorEmail,
    required this.actorRole,
    this.organizationId,
    this.organizationName,
    this.targetId,
    this.targetEmail,
    this.description,
    this.descriptionKey,
    this.metadata,
    this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ActivityLogModel(
      id: id,
      action: json['action'] ?? '',
      actorId: json['actorId'] ?? '',
      actorEmail: json['actorEmail'] ?? '',
      actorRole: json['actorRole'] ?? '',
      organizationId: json['organizationId'] as String?,
      organizationName: json['organizationName'] as String?,
      targetId: json['targetId'] as String?,
      targetEmail: json['targetEmail'] as String?,
      description: json['description'] as String?,
      descriptionKey: json['descriptionKey'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    'actorId': actorId,
    'actorEmail': actorEmail,
    'actorRole': actorRole,
    if (organizationId != null) 'organizationId': organizationId,
    if (organizationName != null) 'organizationName': organizationName,
    if (targetId != null) 'targetId': targetId,
    if (targetEmail != null) 'targetEmail': targetEmail,
    if (description != null) 'description': description,
    if (descriptionKey != null) 'descriptionKey': descriptionKey,
    if (metadata != null) 'metadata': metadata,
    'timestamp': FieldValue.serverTimestamp(),
  };
}
