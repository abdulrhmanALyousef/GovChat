import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/post_model.dart';

/// Streams all posts from every employee using a Firestore collection-group
/// query on `posts`.
///
/// Firestore path: employees/{employeeId}/posts
///
/// Design decisions
/// ────────────────
/// • No `orderBy` in the Firestore query.
///   `orderBy('createdAt')` on a collection-group requires a manually created
///   Firebase Console index. Without it the SDK serves from local cache first
///   (post appears briefly) then the server query fails → `onError` fires →
///   feed clears → post disappears. Sorting is done client-side instead.
///
/// • `includeMetadataChanges: true` + `hasPendingWrites` filter.
///   When a new post is written with `FieldValue.serverTimestamp()`, Firestore
///   stores the doc in the local cache with `hasPendingWrites = true` and
///   resolves `createdAt` to `null` (pending). Including the pending doc in the
///   feed causes flash-and-disappear: it appears briefly from cache, then
///   vanishes once the server re-evaluates the ordered query and the null
///   `createdAt` disqualifies it. Filtering `hasPendingWrites` docs means posts
///   appear exactly once — after the server confirms the write.
///
/// • Empty-URL guard.
///   A post whose `mediaUrls` list contains any empty string is incomplete
///   (upload not fully committed). Such posts are excluded until they are
///   corrected or replaced by the server-confirmed version.
class PostController extends ChangeNotifier {
  PostController() {
    _init();
  }

  List<PostModel> posts = [];
  bool isLoading = true;
  String? errorMessage;

  StreamSubscription<dynamic>? _subscription;

  void _init() {
    _subscription = FirebaseService.instance.firestore
        .collectionGroup('posts')
        // No orderBy here — avoids the collection-group index requirement and
        // the null-createdAt exclusion on pending writes.
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            final confirmed = <PostModel>[];

            for (final doc in snapshot.docs) {
              // Skip documents that have not yet been confirmed by the server.
              // This is the primary guard against flash-and-disappear.
              if (doc.metadata.hasPendingWrites) continue;

              final post = PostModel.fromJson(doc.data(), id: doc.id);

              // Skip posts whose media list contains any empty / blank URL.
              // An empty URL means the upload reference was stored before the
              // Storage write completed — this state should never reach here
              // given the upload contract in CreatePostController, but we guard
              // defensively at the read side as well.
              if (post.mediaUrls.any((url) => url.trim().isEmpty)) continue;

              confirmed.add(post);
            }

            // Sort newest-first on the client.
            confirmed.sort(
              (a, b) => (b.createdAt ?? DateTime(0))
                  .compareTo(a.createdAt ?? DateTime(0)),
            );

            posts = confirmed;
            isLoading = false;
            errorMessage = null;
            notifyListeners();
          },
          onError: (Object e) {
            isLoading = false;
            errorMessage = 'Failed to load posts.';
            notifyListeners();
          },
        );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  /// Deletes the Firestore document for this post.
  /// The caller must verify ownership before invoking this.
  Future<void> deletePost(PostModel post) async {
    if (post.id == null || post.employeeId.isEmpty) return;
    await FirebaseService.instance.firestore
        .collection('employees')
        .doc(post.employeeId)
        .collection('posts')
        .doc(post.id!)
        .delete();
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
