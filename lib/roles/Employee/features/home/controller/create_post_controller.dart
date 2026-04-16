import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/employee_model.dart';
import '../../../../../models/post_model.dart';

class CreatePostController extends ChangeNotifier {
  CreatePostController({required this.employee, PostModel? existingPost})
      : _existingPost = existingPost {
    if (existingPost != null) {
      textController.text = existingPost.text;
      _keptMediaUrls = List<String>.from(existingPost.mediaUrls);
    }
  }

  final EmployeeModel employee;

  /// Non-null when the screen is opened in edit mode.
  final PostModel? _existingPost;

  bool get isEditMode => _existingPost != null;

  final TextEditingController textController = TextEditingController();

  // ─── Media state ─────────────────────────────────────────────────────────

  /// Existing remote URLs from the post being edited that the user wants to keep.
  List<String> _keptMediaUrls = [];
  List<String> get keptMediaUrls => List.unmodifiable(_keptMediaUrls);

  /// New local images picked for this session.
  final List<XFile> _pickedImages = [];
  List<XFile> get pickedImages => List.unmodifiable(_pickedImages);

  /// Combined count of kept remote images + new local picks.
  int get totalMediaCount => _keptMediaUrls.length + _pickedImages.length;

  // ─── State ────────────────────────────────────────────────────────────────

  bool isPosting = false;
  String? errorMessage;

  bool get canPost =>
      !isPosting &&
      (textController.text.trim().isNotEmpty || totalMediaCount > 0);

  void onTextChanged() => notifyListeners();

  // ─── Media actions ────────────────────────────────────────────────────────

  Future<void> pickImages() async {
    final remaining = 4 - totalMediaCount;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    _pickedImages.addAll(picked.take(remaining));
    notifyListeners();
  }

  /// Remove a remote URL that was kept from the existing post.
  void removeKeptMedia(int index) {
    _keptMediaUrls.removeAt(index);
    notifyListeners();
  }

  /// Remove a newly picked local image.
  void removeNewImage(int index) {
    _pickedImages.removeAt(index);
    notifyListeners();
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<bool> submitPost() async {
    final text = textController.text.trim();
    if (text.isEmpty && totalMediaCount == 0) return false;

    isPosting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final employeeId = employee.id ?? '';

      // 1. Upload new images first — Firestore doc is NOT written until every
      //    upload succeeds and returns a valid download URL.
      final newUrls = await _uploadImages(employeeId);

      // 2. Build the final URL list: kept existing remote URLs + newly uploaded.
      final finalUrls = [..._keptMediaUrls, ...newUrls];

      if (isEditMode) {
        // 3a. Update only the changed fields on the existing document.
        await FirebaseService.instance.firestore
            .collection('employees')
            .doc(employeeId)
            .collection('posts')
            .doc(_existingPost!.id!)
            .update({'text': text, 'mediaUrls': finalUrls});
      } else {
        // 3b. Create a new document — only reached if all uploads succeeded.
        final post = PostModel(
          employeeId: employeeId,
          text: text,
          mediaUrls: finalUrls,
          createdByDisplayId: employee.displayId,
          createdByName: employee.name,
        );
        await FirebaseService.instance.firestore
            .collection('employees')
            .doc(employeeId)
            .collection('posts')
            .add(post.toJson());
      }

      isPosting = false;
      notifyListeners();
      return true;
    } catch (_) {
      isPosting = false;
      errorMessage = 'Failed to publish post. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  /// Uploads every picked image and returns the download URLs.
  ///
  /// If any individual upload fails the method rolls back (deletes) all
  /// already-uploaded files for this batch and rethrows, so the caller
  /// never writes a Firestore document with a broken URL list.
  Future<List<String>> _uploadImages(String employeeId) async {
    if (_pickedImages.isEmpty) return [];

    final storage = FirebaseStorage.instance;
    // Track every ref we upload so we can roll back on failure.
    final uploadedRefs = <Reference>[];
    final urls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      for (int i = 0; i < _pickedImages.length; i++) {
        final ref = storage.ref(
          'employees/$employeeId/posts/${timestamp}_$i.jpg',
        );
        uploadedRefs.add(ref);

        // Await the full upload and check the completion state explicitly.
        final snapshot = await ref.putFile(File(_pickedImages[i].path));
        if (snapshot.state != TaskState.success) {
          throw Exception('Upload did not complete successfully for image $i');
        }

        // Only request the download URL after confirming the upload succeeded.
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
      return urls;
    } catch (e) {
      // Rollback: delete every file uploaded in this batch so Storage stays
      // clean and we never reference a partial or missing file in Firestore.
      for (final ref in uploadedRefs) {
        try {
          await ref.delete();
        } catch (_) {
          // Best-effort cleanup — ignore secondary errors.
        }
      }
      rethrow;
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}
