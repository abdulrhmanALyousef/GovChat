import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;

  // Core fields
  final String actionType;
  final String category;
  final String descriptionKey;

  // Actor
  final String performedByUserId;
  final String performedByEmail;
  final String performedByRole;
  final String? performedByName;

  // Organization
  final String? organizationId;
  final String? organizationName;

  // Target
  final String? targetId;
  final String? targetEmail;

  // Metadata (merged)
  final Map<String, dynamic> metadata;

  final DateTime? timestamp;

  const ActivityLogModel({
    this.id,
    required this.actionType,
    required this.category,
    required this.descriptionKey,
    required this.performedByUserId,
    required this.performedByEmail,
    required this.performedByRole,
    this.performedByName,
    this.organizationId,
    this.organizationName,
    this.targetId,
    this.targetEmail,
    this.metadata = const {},
    this.timestamp,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // MERGED fromJson — supports BOTH old and new structures
  // ─────────────────────────────────────────────────────────────────────────────
  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final performedBy = json['performedBy'] as Map<String, dynamic>? ?? {};
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};

    // Pick helper
    String pick(List<dynamic> values) {
      for (final v in values) {
        final s = (v as Object?)?.toString().trim() ?? '';
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    // Action type
    final actionType = pick([json['actionType'], json['action']]);

    // Category
    final rawCategory = pick([json['category']]);
    final category = rawCategory.isNotEmpty
        ? rawCategory
        : _inferCategory(actionType);

    // Description key
    final descKey = pick([json['descriptionKey'], actionType]);

    // Actor
    final userId = pick([performedBy['userId'], json['actorId']]);
    final email = pick([performedBy['email'], json['actorEmail']]);
    final role = pick([performedBy['role'], json['actorRole']]);
    final name = pick([performedBy['name']]);

    // Organization
    final orgId = pick([meta['organizationId'], json['organizationId']]);
    final orgName = pick([meta['organizationName'], json['organizationName']]);

    // Target
    final tgtId = pick([meta['targetId'], json['targetId']]);
    final tgtEmail = pick([meta['targetEmail'], json['targetEmail']]);

    // Timestamp
    final ts = json['timestamp'] is Timestamp
        ? (json['timestamp'] as Timestamp).toDate()
        : null;

    return ActivityLogModel(
      id: id,
      actionType: actionType,
      category: category,
      descriptionKey: descKey,
      performedByUserId: userId,
      performedByEmail: email,
      performedByRole: role,
      performedByName: name.isEmpty ? null : name,
      organizationId: orgId.isEmpty ? null : orgId,
      organizationName: orgName.isEmpty ? null : orgName,
      targetId: tgtId.isEmpty ? null : tgtId,
      targetEmail: tgtEmail.isEmpty ? null : tgtEmail,
      metadata: meta,
      timestamp: ts,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Category inference fallback
  // ─────────────────────────────────────────────────────────────────────────────
  static String _inferCategory(String actionType) {
    if (actionType.contains('login') ||
        actionType.contains('logout') ||
        actionType.contains('password')) {
      return 'authentication';
    }
    if (actionType.startsWith('org_') || actionType.contains('admin')) {
      return 'organization';
    }
    if (actionType.contains('message')) {
      return 'chat';
    }
    return 'employee';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // toJson — unified new structure
  // ─────────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'organizationName': organizationName,
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
      if (targetEmail != null) 'targetEmail': targetEmail,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
