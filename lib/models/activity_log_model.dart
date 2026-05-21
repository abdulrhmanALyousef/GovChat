import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;

  // Core fields
  final String actionType;
  final String category;
  final String descriptionKey;
  final String? description;
  final String? severity;

  // Actor
  final String performedByUserId;
  final String performedByEmail;
  final String performedByRole;
  final String? performedByName;
  final String? performedByEmployeeId;
  final String? performedByDepartmentId;

  // Organization
  final String? organizationId;
  final String? organizationName;

  // Target
  final String? targetId;
  final String? targetType;
  final String? targetName;
  final String? targetEmail;

  // Metadata (merged)
  final Map<String, dynamic> metadata;

  final DateTime? timestamp;

  const ActivityLogModel({
    this.id,
    required this.actionType,
    required this.category,
    required this.descriptionKey,
    this.description,
    this.severity,
    required this.performedByUserId,
    required this.performedByEmail,
    required this.performedByRole,
    this.performedByName,
    this.performedByEmployeeId,
    this.performedByDepartmentId,
    this.organizationId,
    this.organizationName,
    this.targetId,
    this.targetType,
    this.targetName,
    this.targetEmail,
    this.metadata = const {},
    this.timestamp,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // MERGED fromJson — supports both old and new Firestore structures
  // ─────────────────────────────────────────────────────────────────────────────
  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final performedBy = json['performedBy'] as Map<String, dynamic>? ?? {};
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    final target = json['target'] as Map<String, dynamic>? ?? {};

    String pick(List<dynamic> values) {
      for (final v in values) {
        final s = (v as Object?)?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    final actionType = pick([json['actionType'], json['action']]);
    final rawCategory = pick([json['category']]);
    final category = rawCategory.isNotEmpty ? rawCategory : _inferCategory(actionType);
    final descKey = pick([json['descriptionKey'], actionType]);

    final userId = pick([performedBy['userId'], json['actorId']]);
    final email = pick([performedBy['email'], json['actorEmail']]);
    final role = pick([performedBy['role'], json['actorRole']]);
    final name = pick([performedBy['name']]);
    final employeeId = pick([performedBy['employeeId']]);
    final departmentId = pick([performedBy['departmentId']]);

    final orgId = pick([meta['organizationId'], json['organizationId']]);
    final orgName = pick([meta['organizationName'], json['organizationName']]);

    // Target: try nested target object first, then legacy flat fields.
    final tgtId = pick([target['targetId'], meta['targetId'], json['targetId']]);
    final tgtType = pick([target['targetType']]);
    final tgtName = pick([target['targetName']]);
    final tgtEmail = pick([meta['targetEmail'], json['targetEmail']]);

    final ts = json['timestamp'] is Timestamp
        ? (json['timestamp'] as Timestamp).toDate()
        : null;

    return ActivityLogModel(
      id: id,
      actionType: actionType,
      category: category,
      descriptionKey: descKey,
      description: json['description'] as String?,
      severity: json['severity'] as String?,
      performedByUserId: userId,
      performedByEmail: email,
      performedByRole: role,
      performedByName: name.isEmpty ? null : name,
      performedByEmployeeId: employeeId.isEmpty ? null : employeeId,
      performedByDepartmentId: departmentId.isEmpty ? null : departmentId,
      organizationId: orgId.isEmpty ? null : orgId,
      organizationName: orgName.isEmpty ? null : orgName,
      targetId: tgtId.isEmpty ? null : tgtId,
      targetType: tgtType.isEmpty ? null : tgtType,
      targetName: tgtName.isEmpty ? null : tgtName,
      targetEmail: tgtEmail.isEmpty ? null : tgtEmail,
      metadata: meta,
      timestamp: ts,
    );
  }

  static String _inferCategory(String actionType) {
    if (actionType.contains('login') ||
        actionType.contains('logout') ||
        actionType.contains('password') ||
        actionType.contains('otp')) {
      return 'authentication';
    }
    if (actionType.startsWith('org_') || actionType.contains('admin') || actionType.contains('media_sharing')) {
      return 'organizations';
    }
    if (actionType.contains('message') || actionType.contains('media')) {
      return 'chat';
    }
    if (actionType.contains('reminder')) return 'reminders';
    if (actionType.contains('group')) return 'groups';
    if (actionType.contains('announcement')) return 'announcements';
    return 'employee';
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'organizationName': organizationName,
      'category': category,
      'actionType': actionType,
      'severity': severity ?? 'info',
      'description': description,
      'descriptionKey': descriptionKey,
      'performedBy': {
        'userId': performedByUserId,
        'role': performedByRole,
        'email': performedByEmail,
        if (performedByName != null) 'name': performedByName,
        if (performedByEmployeeId != null) 'employeeId': performedByEmployeeId,
        if (performedByDepartmentId != null) 'departmentId': performedByDepartmentId,
      },
      if (targetId != null || targetType != null)
        'target': {
          if (targetId != null) 'targetId': targetId,
          if (targetType != null) 'targetType': targetType,
          if (targetName != null) 'targetName': targetName,
        },
      'metadata': metadata,
      if (targetId != null) 'targetId': targetId,
      if (targetEmail != null) 'targetEmail': targetEmail,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
