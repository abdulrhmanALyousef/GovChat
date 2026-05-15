import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSummary {
  final String mainPoints;
  final String importantDecisions;
  final String tasksAndActionItems;
  final String deadlinesAndCommitments;
  final String overallTone;
  final DateTime generatedAt;

  const ChatSummary({
    required this.mainPoints,
    required this.importantDecisions,
    required this.tasksAndActionItems,
    required this.deadlinesAndCommitments,
    required this.overallTone,
    required this.generatedAt,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      mainPoints: json['mainPoints'] as String? ?? '',
      importantDecisions: json['importantDecisions'] as String? ?? '',
      tasksAndActionItems: json['tasksAndActionItems'] as String? ?? '',
      deadlinesAndCommitments: json['deadlinesAndCommitments'] as String? ?? '',
      overallTone: json['overallTone'] as String? ?? '',
      generatedAt: json['generatedAt'] is Timestamp
          ? (json['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mainPoints': mainPoints,
        'importantDecisions': importantDecisions,
        'tasksAndActionItems': tasksAndActionItems,
        'deadlinesAndCommitments': deadlinesAndCommitments,
        'overallTone': overallTone,
        'generatedAt': FieldValue.serverTimestamp(),
      };
}
