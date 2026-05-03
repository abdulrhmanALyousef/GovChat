import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/comment_model.dart';
import '../../../../../models/post_model.dart';

/// Streams a single post document and its comments subcollection.
///
/// Firestore paths:
///   employees/{employeeId}/posts/{postId}
///   employees/{employeeId}/posts/{postId}/comments/{commentId}
class PostDetailsController extends ChangeNotifier {
  PostDetailsController({
    required this.employeeId,
    required this.postId,
  }) {
    _init();
  }

  final String employeeId;
  final String postId;

  PostModel? post;
  List<CommentModel> comments = [];
  bool isLoading = true;
  String? errorMessage;
  bool isSubmitting = false;

  StreamSubscription<dynamic>? _postSub;
  StreamSubscription<dynamic>? _commentsSub;

  DocumentReference<Map<String, dynamic>> get _postRef =>
      FirebaseService.instance.firestore
          .collection('employees')
          .doc(employeeId)
          .collection('posts')
          .doc(postId);

  void _init() {
    // ── Post stream ──────────────────────────────────────────────────────────
    _postSub = _postRef.snapshots().listen(
      (doc) {
        if (!doc.exists) {
          isLoading = false;
          errorMessage = 'Post not found.';
          notifyListeners();
          return;
        }
        post = PostModel.fromJson(doc.data()!, id: doc.id);
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        isLoading = false;
        errorMessage = 'Failed to load post.';
        notifyListeners();
      },
    );

    // ── Comments stream ──────────────────────────────────────────────────────
    // No orderBy — sort client-side to avoid index requirement.
    // Pending writes are included so added comments appear immediately.
    _commentsSub = _postRef
        .collection('comments')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        final list = <CommentModel>[];
        for (final doc in snapshot.docs) {
          list.add(CommentModel.fromJson(doc.data(), id: doc.id));
        }
        // Sort oldest-first; null createdAt (pending) floats to bottom.
        list.sort(
          (a, b) => (a.createdAt ?? DateTime(9999))
              .compareTo(b.createdAt ?? DateTime(9999)),
        );
        comments = list;
        notifyListeners();
      },
      onError: (Object e) {
        // Non-fatal: keep showing whatever was loaded before.
        notifyListeners();
      },
    );
  }

  // ─── Like ─────────────────────────────────────────────────────────────────

  Future<void> toggleLike(String currentDisplayId) async {
    if (post == null) return;
    final alreadyLiked = post!.likedBy.contains(currentDisplayId);
    await _postRef.update({
      'likedBy': alreadyLiked
          ? FieldValue.arrayRemove([currentDisplayId])
          : FieldValue.arrayUnion([currentDisplayId]),
      'likes': FieldValue.increment(alreadyLiked ? -1 : 1),
    });
  }

  // ─── Add comment ──────────────────────────────────────────────────────────

  /// Atomically adds a comment document and increments [commentsCount].
  Future<void> addComment({
    required String text,
    required String createdByDisplayId,
    required String createdByName,
    required String createdByUid,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSubmitting) return;

    isSubmitting = true;
    notifyListeners();

    try {
      final batch = FirebaseService.instance.firestore.batch();

      final commentRef = _postRef.collection('comments').doc();
      batch.set(
        commentRef,
        CommentModel(
          text: trimmed,
          createdByDisplayId: createdByDisplayId,
          createdByName: createdByName,
          createdByUid: createdByUid,
        ).toJson(),
      );

      batch.update(_postRef, {
        'commentsCount': FieldValue.increment(1),
      });

      await batch.commit();
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _postSub?.cancel();
    _commentsSub?.cancel();
    super.dispose();
  }
}
