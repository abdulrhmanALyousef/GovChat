import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../datasource/remote_data/firebase_service.dart';

/// Fire-and-forget Firestore activity logger.
/// All errors are caught and printed; callers must never await logging calls
/// on the critical path.
class LoggingService {
  static final LoggingService instance = LoggingService._();
  LoggingService._();

  // ── Action type → category mapping ──────────────────────────────────────────
  static const _authTypes = {
    'login_success',
    'login_failure',
    'logout',
    'password_changed',
    'first_login_password_reset',
  };
  static const _employeeTypes = {
    'access_request_submitted',
    'access_request_approved',
    'access_request_rejected',
    'employee_updated',
    'employee_deleted',
  };
  static const _chatTypes = {'message_sent', 'message_deleted'};
  static const _groupTypes = {'project_group_created', 'group_message_sent', 'project_group_deleted'};
  static const _reminderTypes = {
    'reminder_created',
    'reminder_updated',
    'reminder_completed',
    'reminder_deleted',
  };

  String _categoryFor(String actionType) {
    if (_authTypes.contains(actionType)) return 'authentication';
    if (_employeeTypes.contains(actionType)) return 'employee';
    if (_chatTypes.contains(actionType)) return 'chat';
    if (_groupTypes.contains(actionType)) return 'groups';
    if (_reminderTypes.contains(actionType)) return 'reminders';
    return 'security';
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Writes a single log entry to the `logs` collection.
  /// organizationId must be non-empty; otherwise the call is a no-op.
  Future<void> log({
    required String organizationId,
    required String actionType,
    required String descriptionKey,
    required String performedByUserId,
    required String performedByRole,
    required String performedByEmail,
    String? performedByName,
    String? targetId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (organizationId.isEmpty) return;
    try {
      final performedBy = <String, dynamic>{
        'userId': performedByUserId,
        'role': performedByRole,
        'email': performedByEmail,
        if (performedByName != null && performedByName != performedByEmail)
          'name': performedByName,
      };

      final doc = <String, dynamic>{
        'organizationId': organizationId,
        'category': _categoryFor(actionType),
        'actionType': actionType,
        'descriptionKey': descriptionKey,
        'performedBy': performedBy,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (targetId != null) doc['targetId'] = targetId;

      await FirebaseService.instance.firestore.collection('logs').add(doc);
    } catch (e) {
      debugPrint('[LoggingService] Failed to write log ($actionType): $e');
    }
  }
}
