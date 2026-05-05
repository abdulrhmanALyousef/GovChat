import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/employee_model.dart';
import '../../../../../models/project_group_model.dart';

class AdminGroupsController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  List<ProjectGroupModel> groups = [];
  List<EmployeeModel> employees = [];
  bool isLoading = true;
  String? errorMessage;

  AdminModel? currentAdmin;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsSub;

  AdminGroupsController() {
    _init();
  }

  Future<void> _init() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = _firebase.currentUser;
      if (user == null) {
        errorMessage = 'User not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await _firebase.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        errorMessage = 'Admin data not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      currentAdmin = AdminModel.fromJson(doc.data()!);
      final orgId = currentAdmin?.organizationId;

      if (orgId == null || orgId.isEmpty) {
        errorMessage = 'Organization not found for this admin account';
        isLoading = false;
        notifyListeners();
        return;
      }

      await _loadEmployees(orgId);
      _listenToGroups(orgId);
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEmployees(String orgId) async {
    try {
      final snapshot = await _firebase.firestore
          .collection('employees')
          .where('organizationId', isEqualTo: orgId)
          .where('role', isEqualTo: 'employee')
          .where('status', isEqualTo: 'active')
          .get();

      employees = snapshot.docs
          .map((doc) => EmployeeModel.fromJson(doc.data(), id: doc.id))
          .toList();
      employees.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      debugPrint('[AdminGroupsController] Failed to load employees: $e');
    }
  }

  void _listenToGroups(String orgId) {
    _groupsSub?.cancel();
    _groupsSub = _firebase.firestore
        .collection('projectGroups')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            groups = snapshot.docs
                .map((doc) =>
                    ProjectGroupModel.fromJson(doc.data(), id: doc.id))
                .toList();
            isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            errorMessage = e.toString();
            isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final orgId = currentAdmin?.organizationId;
    final uid = _firebase.currentUser?.uid;
    if (orgId == null || orgId.isEmpty || uid == null) return;

    final group = ProjectGroupModel(
      organizationId: orgId,
      name: name.trim(),
      createdBy: uid,
      memberIds: memberIds,
    );

    await _firebase.firestore.collection('projectGroups').add(group.toJson());

    LoggingService.instance.log(
      actionType: 'PROJECT_GROUP_CREATED',
      category: 'groups',
      descriptionKey: 'logProjectGroupCreated',
      metadata: {
        'groupName': name.trim(),
        'memberCount': memberIds.length,
      },
    ).ignore();
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    super.dispose();
  }
}
