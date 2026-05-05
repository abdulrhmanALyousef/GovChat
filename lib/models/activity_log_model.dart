import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? logId;
  final String organizationId;
  final String category; // 'authentication' | 'employee' | 'chat' | 'security'
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
    this.logId,
    required this.organizationId,
    required this.category,
    required this.actionType,
    required this.descriptionKey,
    required this.performedByUserId,
    required this.performedByRole,
    this.performedByName,
    this.targetId,
    this.metadata = const {},
    this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime? ts;
    final raw = json['timestamp'];
    if (raw is Timestamp) ts = raw.toDate();

    final performedBy = json['performedBy'] as Map<String, dynamic>?;
    return ActivityLogModel(
      logId: id,
      organizationId: json['organizationId'] as String? ?? '',
      category: json['category'] as String? ?? 'security',
      actionType: json['actionType'] as String? ?? '',
      descriptionKey: json['descriptionKey'] as String? ?? '',
      performedByUserId: performedBy?['userId'] as String? ?? '',
      performedByRole: performedBy?['role'] as String? ?? '',
      performedByName: performedBy?['name'] as String?,
      targetId: json['targetId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      timestamp: ts,
    );
  }
}
