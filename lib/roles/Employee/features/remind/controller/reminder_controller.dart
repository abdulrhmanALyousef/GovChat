import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../core/services/logging_service.dart';
import '../../../../../core/services/notification_service.dart';
import '../../../../../models/employee_model.dart';
import '../../../../../models/reminder_model.dart';
import '../data/reminder_repository.dart';

enum ReminderFilter { all, active, overdue, completed, highPriority }

class ReminderController extends ChangeNotifier {
  final EmployeeModel employee;

  ReminderController({required this.employee}) {
    _init();
  }

  final _repo = ReminderRepository.instance;
  final _notif = NotificationService.instance;

  List<ReminderModel> _reminders = [];
  String _searchQuery = '';
  ReminderFilter _filter = ReminderFilter.all;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<ReminderModel>>? _sub;

  bool get isLoading => _isLoading;
  String? get error => _error;
  ReminderFilter get filter => _filter;
  String get searchQuery => _searchQuery;

  List<ReminderModel> get filteredReminders {
    var list = _reminders;

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q);
      }).toList();
    }

    // Filter
    switch (_filter) {
      case ReminderFilter.active:
        list = list.where((r) => !r.isCompleted && !r.isOverdue).toList();
        break;
      case ReminderFilter.overdue:
        list = list.where((r) => r.isOverdue).toList();
        break;
      case ReminderFilter.completed:
        list = list.where((r) => r.isCompleted).toList();
        break;
      case ReminderFilter.highPriority:
        list = list
            .where((r) =>
                r.priority == ReminderPriority.high && !r.isCompleted)
            .toList();
        break;
      case ReminderFilter.all:
        break;
    }

    return list;
  }

  int get activeCount =>
      _reminders.where((r) => !r.isCompleted && !r.isOverdue).length;
  int get overdueCount => _reminders.where((r) => r.isOverdue).length;

  void _init() {
    _sub = _repo
        .watchReminders(employee.id ?? '')
        .listen(
          (data) {
            _reminders = data;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void setFilter(ReminderFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> createReminder(ReminderModel reminder) async {
    try {
      final saved = await _repo.create(reminder);
      await _notif.scheduleReminder(saved);
      _logReminder('reminder_created', 'logReminderCreated', saved.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    try {
      await _repo.update(reminder);
      // Cancel old notification and reschedule
      await _notif.cancelReminder(reminder.id);
      await _notif.scheduleReminder(reminder);
      _logReminder('reminder_updated', 'logReminderUpdated', reminder.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteReminder(ReminderModel reminder) async {
    try {
      await _notif.cancelReminder(reminder.id);
      await _repo.delete(employee.id ?? '', reminder.id);
      _logReminder('reminder_deleted', 'logReminderDeleted', reminder.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleComplete(ReminderModel reminder) async {
    final updated = reminder.copyWith(
      isCompleted: !reminder.isCompleted,
      updatedAt: DateTime.now(),
    );
    try {
      await _repo.update(updated);
      if (updated.isCompleted) {
        await _notif.cancelReminder(reminder.id);
        _logReminder(
            'reminder_completed', 'logReminderCompleted', reminder.id);
      } else {
        await _notif.scheduleReminder(updated);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _logReminder(
      String actionType, String descriptionKey, String reminderId) {
    if (employee.organizationId.isEmpty) return;
    LoggingService.instance
        .log(
          organizationId: employee.organizationId,
          actionType: actionType,
          descriptionKey: descriptionKey,
          performedByUserId: employee.id ?? '',
          performedByRole: 'employee',
          performedByEmail: employee.email,
          performedByName: employee.name,
          targetId: reminderId,
        )
        .ignore();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
