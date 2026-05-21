import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderPriority { low, medium, high }

enum ReminderRepeatType { none, daily, weekly, monthly, custom }

class ReminderModel {
  final String id;
  final String employeeId;
  final String organizationId;
  final String title;
  final String description;
  final ReminderPriority priority;
  final DateTime dueDate;
  final int remindBeforeMinutes;
  final ReminderRepeatType repeatType;
  final int repeatInterval;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastTriggeredAt;
  final bool notificationEnabled;

  const ReminderModel({
    required this.id,
    required this.employeeId,
    required this.organizationId,
    required this.title,
    this.description = '',
    required this.priority,
    required this.dueDate,
    this.remindBeforeMinutes = 0,
    this.repeatType = ReminderRepeatType.none,
    this.repeatInterval = 1,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastTriggeredAt,
    this.notificationEnabled = true,
  });

  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());

  String get statusKey {
    if (isCompleted) return 'completed';
    if (isOverdue) return 'overdue';
    return 'active';
  }

  DateTime get notificationTime =>
      dueDate.subtract(Duration(minutes: remindBeforeMinutes));

  ReminderModel copyWith({
    String? id,
    String? employeeId,
    String? organizationId,
    String? title,
    String? description,
    ReminderPriority? priority,
    DateTime? dueDate,
    int? remindBeforeMinutes,
    ReminderRepeatType? repeatType,
    int? repeatInterval,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastTriggeredAt,
    bool? notificationEnabled,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      remindBeforeMinutes: remindBeforeMinutes ?? this.remindBeforeMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'organizationId': organizationId,
        'title': title,
        'description': description,
        'priority': priority.name,
        'dueDate': Timestamp.fromDate(dueDate),
        'remindBeforeMinutes': remindBeforeMinutes,
        'repeatType': repeatType.name,
        'repeatInterval': repeatInterval,
        'isCompleted': isCompleted,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        if (lastTriggeredAt != null)
          'lastTriggeredAt': Timestamp.fromDate(lastTriggeredAt!),
        'notificationEnabled': notificationEnabled,
      };

  factory ReminderModel.fromJson(String id, Map<String, dynamic> json) {
    return ReminderModel(
      id: id,
      employeeId: json['employeeId'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: ReminderPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => ReminderPriority.medium,
      ),
      dueDate: (json['dueDate'] as Timestamp).toDate(),
      remindBeforeMinutes: json['remindBeforeMinutes'] as int? ?? 0,
      repeatType: ReminderRepeatType.values.firstWhere(
        (e) => e.name == json['repeatType'],
        orElse: () => ReminderRepeatType.none,
      ),
      repeatInterval: json['repeatInterval'] as int? ?? 1,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt:
          (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastTriggeredAt: (json['lastTriggeredAt'] as Timestamp?)?.toDate(),
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
    );
  }
}
