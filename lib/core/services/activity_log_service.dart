import 'package:cloud_firestore/cloud_firestore.dart';

import '../datasource/remote_data/firebase_service.dart';

class ActivityLogService {
  ActivityLogService._();
  static final ActivityLogService instance = ActivityLogService._();

  static const String actionLogin = 'login';
  static const String actionLogout = 'logout';
  static const String actionOrgCreated = 'org_created';
  static const String actionOrgUpdated = 'org_updated';
  static const String actionOrgDeleted = 'org_deleted';
  static const String actionAdminCreated = 'admin_created';
  static const String actionEmployeeApproved = 'employee_approved';
  static const String actionEmployeeRejected = 'employee_rejected';
  static const String actionEmployeeUpdated = 'employee_updated';
  static const String actionEmployeeDeleted = 'employee_deleted';
  static const String actionPasswordChanged = 'password_changed';
  static const String actionRequestSubmitted = 'request_submitted';

  Future<void> log({
    required String action,
    required String actorId,
    required String actorEmail,
    required String actorRole,
    String? organizationId,
    String? organizationName,
    String? targetId,
    String? targetEmail,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final resolvedEmail =
          actorEmail.trim().isNotEmpty ? actorEmail.trim() : 'unknown@system';
      await FirebaseService.instance.firestore.collection('logs').add({
        'action': action,
        'actorId': actorId,
        'actorEmail': resolvedEmail,
        'actorRole': actorRole,
        'descriptionKey': action,
        if (organizationId != null) 'organizationId': organizationId,
        if (organizationName != null) 'organizationName': organizationName,
        if (targetId != null) 'targetId': targetId,
        if (targetEmail != null) 'targetEmail': targetEmail,
        if (metadata != null) 'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let logging crash the app
    }
  }

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
