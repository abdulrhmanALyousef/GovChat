import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;
  final String organizationId;
  final String category; // 'authentication' | 'employee' | 'chat' | 'groups' | 'security'
  final String actionType; // non-localized enum string, e.g. 'login_success'
  final String descriptionKey; // ARB camelCase key, e.g. 'logLoginSuccess'
  final String performedByUserId;
  final String performedByRole;
  final String performedByEmail;
  final String? performedByName;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime? timestamp;

  const ActivityLogModel({
    this.id,
    required this.organizationId,
    required this.category,
    required this.actionType,
    required this.descriptionKey,
    required this.performedByUserId,
    required this.performedByRole,
    required this.performedByEmail,
    this.performedByName,
    this.targetId,
    this.metadata = const {},
    this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime? ts;
    final raw = json['timestamp'];
    if (raw is Timestamp) ts = raw.toDate();

    final performedBy = json['performedBy'] as Map<String, dynamic>? ?? {};
    return ActivityLogModel(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      category: json['category'] as String? ?? 'security',
      actionType: json['actionType'] as String? ?? '',
      descriptionKey: json['descriptionKey'] as String? ?? '',
      performedByUserId: performedBy['userId'] as String? ?? '',
      performedByRole: performedBy['role'] as String? ?? '',
      performedByEmail: performedBy['email'] as String? ?? '',
      performedByName: performedBy['name'] as String?,
      targetId: json['targetId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'category': category,
      'actionType': actionType,
      'descriptionKey': descriptionKey,
      'performedBy': {
        'userId': performedByUserId,
        'role': performedByRole,
        'email': performedByEmail,
        if (performedByName != null) 'name': performedByName,
      },
      'metadata': metadata,
      if (targetId != null) 'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
