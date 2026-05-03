import 'package:cloud_firestore/cloud_firestore.dart';

/// A single comment on a post.
///
/// Firestore path: employees/{employeeId}/posts/{postId}/comments/{commentId}
class CommentModel {
  final String? id;
  final String text;
  final DateTime? createdAt;
  final String createdByDisplayId;
  final String createdByName;
  final String createdByUid;

  const CommentModel({
    this.id,
    required this.text,
    this.createdAt,
    required this.createdByDisplayId,
    required this.createdByName,
    this.createdByUid = '',
  });

  factory CommentModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return CommentModel(
      id: id,
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      createdByDisplayId: json['createdByDisplayId'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      createdByUid: json['createdByUid'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByDisplayId': createdByDisplayId,
      'createdByName': createdByName,
      if (createdByUid.isNotEmpty) 'createdByUid': createdByUid,
    };
  }
}
