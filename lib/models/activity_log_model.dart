import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String? id;
  final String actionType;
  final String category;
  final String descriptionKey;
  final Map<String, dynamic> metadata;
  final String performedByUserId;
  final String performedByEmail;
  final String performedByRole;
  final DateTime? timestamp;

  ActivityLogModel({
    this.id,
    required this.actionType,
    required this.category,
    required this.descriptionKey,
    this.metadata = const {},
    required this.performedByUserId,
    required this.performedByEmail,
    required this.performedByRole,
    this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final performedBy = json['performedBy'] as Map<String, dynamic>? ?? {};
    return ActivityLogModel(
      id: id,
      actionType: json['actionType'] as String? ?? '',
      category: json['category'] as String? ?? '',
      descriptionKey: json['descriptionKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      performedByUserId: performedBy['userId'] as String? ?? '',
      performedByEmail: performedBy['email'] as String? ?? '',
      performedByRole: performedBy['role'] as String? ?? '',
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'category': category,
      'descriptionKey': descriptionKey,
      'metadata': metadata,
      'performedBy': {
        'userId': performedByUserId,
        'email': performedByEmail,
        'role': performedByRole,
      },
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
