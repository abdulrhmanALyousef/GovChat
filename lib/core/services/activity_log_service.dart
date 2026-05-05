import 'package:cloud_firestore/cloud_firestore.dart';

import '../datasource/remote_data/firebase_service.dart';

class ActivityLogService {
  ActivityLogService._();
  static final ActivityLogService instance = ActivityLogService._();

  // ── Action constants ────────────────────────────────────────────────
  static const String actionLogin              = 'login';
  static const String actionLogout             = 'logout';
  static const String actionOrgCreated         = 'org_created';
  static const String actionOrgUpdated         = 'org_updated';
  static const String actionOrgDeleted         = 'org_deleted';
  static const String actionAdminCreated       = 'admin_created';
  static const String actionEmployeeApproved   = 'employee_approved';
  static const String actionEmployeeRejected   = 'employee_rejected';
  static const String actionEmployeeUpdated    = 'employee_updated';
  static const String actionEmployeeDeleted    = 'employee_deleted';
  static const String actionPasswordChanged    = 'password_changed';
  static const String actionRequestSubmitted   = 'request_submitted';

  // ── Write a log entry ───────────────────────────────────────────────
  Future<void> log({
    required String actionType,
    required String userId,
    required String email,
    required String role,
    String? organizationId,
    String? organizationName,
    String? targetId,
    String? targetEmail,
  }) async {
    try {
      final resolvedEmail =
          email.trim().isNotEmpty ? email.trim() : 'unknown@system';

      final metadata = <String, dynamic>{};
      if (organizationId != null)   metadata['organizationId']   = organizationId;
      if (organizationName != null) metadata['organizationName'] = organizationName;
      if (targetId != null)         metadata['targetId']         = targetId;
      if (targetEmail != null)      metadata['targetEmail']      = targetEmail;

      await FirebaseService.instance.firestore.collection('logs').add({
        'actionType':     actionType,
        'category':       _categoryFor(actionType),
        'descriptionKey': actionType,
        'performedBy': {
          'userId': userId,
          'email':  resolvedEmail,
          'role':   role,
        },
        'metadata':  metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let logging crash the app
    }
  }

  String _categoryFor(String actionType) {
    switch (actionType) {
      case actionLogin:
      case actionLogout:
      case actionPasswordChanged:
        return 'auth';
      case actionOrgCreated:
      case actionOrgUpdated:
      case actionOrgDeleted:
      case actionAdminCreated:
        return 'organization';
      default:
        return 'employee';
    }
  }

  // ── Update lastLoginAt on the user document ─────────────────────────
  Future<void> updateLoginActivity({String? deviceInfo}) async {
    final user = FirebaseService.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseService.instance.firestore
          .collection('users')
          .doc(user.uid)
          .update({
            'lastLoginAt': FieldValue.serverTimestamp(),
            if (deviceInfo != null) 'lastDevice': deviceInfo,
          });
    } catch (_) {}
  }
}
