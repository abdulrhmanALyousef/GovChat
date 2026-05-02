import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;
  final String actionType;
  final String category;
  final String descriptionKey;
  final String performedByUserId;
  final String performedByEmail;
  final String performedByRole;
  final String? organizationId;
  final String? organizationName;
  final String? targetId;
  final String? targetEmail;
  final DateTime? timestamp;

  const ActivityLogModel({
    this.id,
    required this.actionType,
    required this.category,
    required this.descriptionKey,
    required this.performedByUserId,
    required this.performedByEmail,
    required this.performedByRole,
    this.organizationId,
    this.organizationName,
    this.targetId,
    this.targetEmail,
    this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    // New structure uses nested maps; old structure uses flat fields.
    final performedBy = json['performedBy'] as Map<String, dynamic>?;
    final metadata    = json['metadata']    as Map<String, dynamic>?;

    final actionType = _pick([json['actionType'], json['action']]);
    final rawCategory = _pick([json['category']]);
    final category    = rawCategory.isNotEmpty ? rawCategory : _inferCategory(actionType);
    final rawDescKey  = _pick([json['descriptionKey']]);
    final descKey     = rawDescKey.isNotEmpty ? rawDescKey : actionType;

    final userId = _pick([performedBy?['userId'], json['actorId']]);
    final email  = _pick([performedBy?['email'],  json['actorEmail']]);
    final role   = _pick([performedBy?['role'],   json['actorRole']]);

    final orgId   = _pick([metadata?['organizationId'],   json['organizationId']]);
    final orgName = _pick([metadata?['organizationName'], json['organizationName']]);
    final tgtId   = _pick([metadata?['targetId'],         json['targetId']]);
    final tgtEmail= _pick([metadata?['targetEmail'],      json['targetEmail']]);

    return ActivityLogModel(
      id: id,
      actionType: actionType,
      category: category,
      descriptionKey: descKey,
      performedByUserId: userId,
      performedByEmail: email,
      performedByRole: role,
      organizationId: orgId.isEmpty ? null : orgId,
      organizationName: orgName.isEmpty ? null : orgName,
      targetId: tgtId.isEmpty ? null : tgtId,
      targetEmail: tgtEmail.isEmpty ? null : tgtEmail,
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  // Returns the first non-null, non-empty string from [values].
  static String _pick(List<dynamic> values) {
    for (final v in values) {
      final s = (v as Object?)?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _inferCategory(String actionType) {
    if (actionType == 'login' ||
        actionType == 'logout' ||
        actionType == 'password_changed') return 'auth';
    if (actionType.startsWith('org_') || actionType == 'admin_created') {
      return 'organization';
    }
    return 'employee';
  }
}
