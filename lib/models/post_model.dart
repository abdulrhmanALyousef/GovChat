import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String? id;

  /// UID of the employee who owns this post.
  final String employeeId;

  final String text;
  final List<String> mediaUrls;
  final DateTime? createdAt;
  final String createdByDisplayId;
  final String createdByName;
  final int likes;
  final int commentsCount;

  /// Display-IDs of employees who have liked this post.
  final List<String> likedBy;

  const PostModel({
    this.id,
    required this.employeeId,
    required this.text,
    required this.mediaUrls,
    this.createdAt,
    required this.createdByDisplayId,
    required this.createdByName,
    this.likes = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
  });

  factory PostModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return PostModel(
      id: id,
      employeeId: json['employeeId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      mediaUrls: List<String>.from(
        (json['mediaUrls'] as List<dynamic>?) ?? [],
      ),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      createdByDisplayId: json['createdByDisplayId'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(
        (json['likedBy'] as List<dynamic>?) ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'text': text,
      'mediaUrls': mediaUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByDisplayId': createdByDisplayId,
      'createdByName': createdByName,
      'likes': likes,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
    };
  }

  PostModel copyWith({
    String? text,
    List<String>? mediaUrls,
    int? likes,
    int? commentsCount,
    List<String>? likedBy,
  }) {
    return PostModel(
      id: id,
      employeeId: employeeId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt,
      createdByDisplayId: createdByDisplayId,
      createdByName: createdByName,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
