import 'package:flutter/foundation.dart';

import '../datasource/remote_data/firebase_service.dart';
import '../../models/activity_log_model.dart';

class LoggingService {
  LoggingService._();
  static final LoggingService instance = LoggingService._();

  Future<void> log({
    required String actionType,
    required String category,
    required String descriptionKey,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final user = FirebaseService.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseService.instance.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      final orgId = (data['organizationId'] ?? '') as String;

      final logEntry = ActivityLogModel(
        actionType: actionType,
        category: category,
        descriptionKey: descriptionKey,
        metadata: {
          'organizationId': orgId,
          ...metadata,
        },
        performedByUserId: user.uid,
        performedByEmail: user.email ?? '',
        performedByRole: (data['role'] ?? '') as String,
      );

      await FirebaseService.instance.firestore
          .collection('organizations')
          .doc(orgId)
          .collection('activityLogs')
          .add(logEntry.toJson());
    } catch (e) {
      debugPrint('[LoggingService] Failed to write log: $e');
    }
  }
}
