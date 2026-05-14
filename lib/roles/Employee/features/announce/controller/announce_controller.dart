import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/announcement_model.dart';
import '../../../../../models/employee_model.dart';

class AnnounceController extends ChangeNotifier {
  AnnounceController(this.employee) {
    _init();
  }

  final EmployeeModel employee;

  List<AnnouncementModel> _announcements = [];
  List<AnnouncementModel> get announcements => _announcements;

  bool isLoading = true;
  String? errorMessage;

  StreamSubscription<QuerySnapshot>? _sub;

  void _init() {
    final orgId = employee.organizationId;
    if (orgId.isEmpty) {
      isLoading = false;
      notifyListeners();
      return;
    }

    final q = FirebaseService.instance.firestore
        .collection('announcements')
        .where('organizationId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    _sub = q.snapshots().listen(
      (snap) {
        final now = DateTime.now();
        _announcements = snap.docs
            .map((d) => AnnouncementModel.fromJson(
                  d.data(),
                  d.id,
                ))
            .where((a) => a.expiresAt == null || a.expiresAt!.isAfter(now))
            .toList();
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        isLoading = false;
        errorMessage = e.toString();
        debugPrint('[AnnounceController] Stream error: $e');
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
