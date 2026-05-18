import 'package:cloud_firestore/cloud_firestore.dart';

class InboxSummary {
  final String highlights;
  final String urgentItems;
  final String decisions;
  final String pendingItems;
  final String perChatBreakdown;
  final String trends;
  final DateTime generatedAt;

  const InboxSummary({
    required this.highlights,
    required this.urgentItems,
    required this.decisions,
    required this.pendingItems,
    required this.perChatBreakdown,
    required this.trends,
    required this.generatedAt,
  });

  factory InboxSummary.fromJson(Map<String, dynamic> json) {
    return InboxSummary(
      highlights: json['highlights'] as String? ?? '',
      urgentItems: json['urgentItems'] as String? ?? '',
      decisions: json['decisions'] as String? ?? '',
      pendingItems: json['pendingItems'] as String? ?? '',
      perChatBreakdown: json['perChatBreakdown'] as String? ?? '',
      trends: json['trends'] as String? ?? '',
      generatedAt: json['generatedAt'] is Timestamp
          ? (json['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'highlights': highlights,
        'urgentItems': urgentItems,
        'decisions': decisions,
        'pendingItems': pendingItems,
        'perChatBreakdown': perChatBreakdown,
        'trends': trends,
        'generatedAt': FieldValue.serverTimestamp(),
      };
}
