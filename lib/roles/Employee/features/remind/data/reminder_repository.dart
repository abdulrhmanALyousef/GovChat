import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/reminder_model.dart';

class ReminderRepository {
  ReminderRepository._();
  static final ReminderRepository instance = ReminderRepository._();

  CollectionReference<Map<String, dynamic>> _col(String employeeId) =>
      FirebaseService.instance.firestore
          .collection('employees')
          .doc(employeeId)
          .collection('reminders');

  Stream<List<ReminderModel>> watchReminders(String employeeId) {
    return _col(employeeId)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReminderModel.fromJson(d.id, d.data()))
            .toList());
  }

  Future<ReminderModel> create(ReminderModel reminder) async {
    final doc = await _col(reminder.employeeId).add(reminder.toJson());
    return reminder.copyWith(id: doc.id);
  }

  Future<void> update(ReminderModel reminder) async {
    await _col(reminder.employeeId)
        .doc(reminder.id)
        .update(reminder.toJson());
  }

  Future<void> delete(String employeeId, String reminderId) async {
    try {
      await _col(employeeId).doc(reminderId).delete();
    } catch (e) {
      debugPrint('[ReminderRepository] delete error: $e');
    }
  }
}
