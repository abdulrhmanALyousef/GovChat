import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../datasource/remote_data/firebase_service.dart';

/// Professional, fire-and-forget audit logger.
/// All errors are caught and printed; callers must never await on the critical path.
class LoggingService {
  static final LoggingService instance = LoggingService._();
  LoggingService._();

  // ── Category mapping ──────────────────────────────────────────────────────
  static const _authTypes = {
    'login_success', 'login_failure', 'logout', 'auto_logout_inactivity',
    'password_changed', 'password_reset_requested', 'password_reset_completed',
    'first_login_password_reset', 'password_change_otp_sent',
    'otp_sent', 'otp_verified', 'otp_failed',
  };
  static const _employeeTypes = {
    'access_request_submitted', 'access_request_approved',
    'access_request_rejected', 'employee_updated', 'employee_deleted',
    'employee_approved', 'employee_rejected',
  };
  static const _chatTypes = {
    'message_sent', 'message_edited', 'message_deleted', 'media_uploaded',
  };
  static const _groupTypes = {
    'project_group_created', 'group_message_sent', 'project_group_deleted',
    'group_member_added', 'group_member_removed',
  };
  static const _reminderTypes = {
    'reminder_created', 'reminder_updated', 'reminder_completed', 'reminder_deleted',
  };
  static const _announcementTypes = {
    'announcement_created', 'announcement_updated',
    'announcement_deleted', 'announcement_viewed',
  };
  static const _profileTypes = {'profile_updated', 'avatar_changed'};
  static const _organizationTypes = {
    'org_created', 'org_updated', 'org_deleted', 'admin_created',
    'media_sharing_enabled', 'media_sharing_disabled',
  };

  // ── Severity mapping ──────────────────────────────────────────────────────
  static const _criticalTypes = {
    'unauthorized_access', 'role_misuse_attempt', 'suspicious_login',
  };
  static const _highTypes = {
    'password_changed', 'password_reset_completed', 'first_login_password_reset',
    'employee_deleted', 'employee_approved', 'access_request_approved',
    'admin_created', 'org_deleted', 'media_sharing_disabled',
  };
  static const _warningTypes = {
    'login_failure', 'otp_failed', 'message_deleted', 'auto_logout_inactivity',
    'access_request_rejected', 'employee_rejected',
  };

  // ── Human-readable descriptions ───────────────────────────────────────────
  static const _descriptions = <String, String>{
    'login_success': 'Employee logged in successfully',
    'login_failure': 'Login attempt failed',
    'logout': 'Employee logged out',
    'auto_logout_inactivity': 'Session ended due to inactivity',
    'password_changed': 'Password changed successfully',
    'password_reset_requested': 'Password reset requested',
    'password_reset_completed': 'Password reset completed',
    'first_login_password_reset': 'First-time password reset',
    'password_change_otp_sent': 'OTP sent for password change',
    'otp_sent': 'OTP verification code sent',
    'otp_verified': 'OTP verified successfully',
    'otp_failed': 'OTP verification failed',
    'access_request_submitted': 'New employee access request submitted',
    'access_request_approved': 'Employee access request approved',
    'access_request_rejected': 'Employee access request rejected',
    'employee_updated': 'Employee profile updated',
    'employee_deleted': 'Employee account deactivated',
    'employee_approved': 'Employee account approved and activated',
    'employee_rejected': 'Employee account rejected',
    'message_sent': 'Message sent',
    'message_edited': 'Message edited',
    'message_deleted': 'Message deleted',
    'media_uploaded': 'Media file uploaded',
    'project_group_created': 'Project group created',
    'group_message_sent': 'Message sent in project group',
    'project_group_deleted': 'Project group deleted',
    'group_member_added': 'Member added to group',
    'group_member_removed': 'Member removed from group',
    'reminder_created': 'Reminder created',
    'reminder_updated': 'Reminder updated',
    'reminder_completed': 'Reminder marked as completed',
    'reminder_deleted': 'Reminder deleted',
    'announcement_created': 'Announcement created',
    'announcement_updated': 'Announcement updated',
    'announcement_deleted': 'Announcement deleted',
    'announcement_viewed': 'Announcement viewed',
    'profile_updated': 'Profile information updated',
    'avatar_changed': 'Profile picture changed',
    'org_created': 'Organization created',
    'org_updated': 'Organization updated',
    'org_deleted': 'Organization deleted',
    'admin_created': 'Admin account created',
    'media_sharing_enabled': 'Media sharing enabled for organization',
    'media_sharing_disabled': 'Media sharing disabled for organization',
    'unauthorized_access': 'Unauthorized access attempt detected',
    'role_misuse_attempt': 'Role misuse attempt detected',
    'suspicious_login': 'Suspicious login activity detected',
  };

  String _categoryFor(String actionType) {
    if (_authTypes.contains(actionType)) return 'authentication';
    if (_employeeTypes.contains(actionType)) return 'employee';
    if (_chatTypes.contains(actionType)) return 'chat';
    if (_groupTypes.contains(actionType)) return 'groups';
    if (_reminderTypes.contains(actionType)) return 'reminders';
    if (_announcementTypes.contains(actionType)) return 'announcements';
    if (_profileTypes.contains(actionType)) return 'profile';
    if (_organizationTypes.contains(actionType)) return 'organizations';
    return 'security';
  }

  String _severityFor(String actionType) {
    if (_criticalTypes.contains(actionType)) return 'critical';
    if (_highTypes.contains(actionType)) return 'high';
    if (_warningTypes.contains(actionType)) return 'warning';
    return 'info';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Writes a single structured audit log entry to the `logs` collection.
  /// organizationId must be non-empty; otherwise the call is a no-op.
  /// All parameters except the three required ones are optional.
  Future<void> log({
    required String organizationId,
    required String actionType,
    required String performedByUserId,
    required String performedByRole,
    required String performedByEmail,
    String? performedByName,
    String? performedByEmployeeId,
    String? performedByDepartmentId,
    String? targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic> metadata = const {},
    // Kept for backward compatibility with existing call sites.
    String? descriptionKey,
  }) async {
    if (organizationId.isEmpty) return;
    try {
      final performedBy = <String, dynamic>{
        'userId': performedByUserId,
        'role': performedByRole,
        'email': performedByEmail,
        if (performedByName != null && performedByName.isNotEmpty)
          'name': performedByName,
        if (performedByEmployeeId != null && performedByEmployeeId.isNotEmpty)
          'employeeId': performedByEmployeeId,
        if (performedByDepartmentId != null && performedByDepartmentId.isNotEmpty)
          'departmentId': performedByDepartmentId,
      };

      final doc = <String, dynamic>{
        'organizationId': organizationId,
        'category': _categoryFor(actionType),
        'actionType': actionType,
        'severity': _severityFor(actionType),
        'description': _descriptions[actionType] ?? actionType,
        'descriptionKey': descriptionKey ?? actionType,
        'performedBy': performedBy,
        'metadata': metadata,
        'visibility': {'adminVisible': true, 'primaryAdminVisible': true},
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Nested target object for structured target references.
      if (targetId != null || targetType != null) {
        doc['target'] = <String, dynamic>{
          // ignore: use_null_aware_elements
          if (targetId != null) 'targetId': targetId,
          // ignore: use_null_aware_elements
          if (targetType != null) 'targetType': targetType,
          // ignore: use_null_aware_elements
          if (targetName != null) 'targetName': targetName,
        };
      }
      // Top-level targetId for backward compat with older queries.
      if (targetId != null) doc['targetId'] = targetId;

      await FirebaseService.instance.firestore.collection('logs').add(doc);
    } catch (e) {
      debugPrint('[LoggingService] Failed to write log ($actionType): $e');
    }
  }
}
