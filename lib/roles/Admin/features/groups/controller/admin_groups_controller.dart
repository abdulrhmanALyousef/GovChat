import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/employee_model.dart';
import '../../../../../models/project_group_model.dart';
import '../../../../../models/unified_group.dart';

class AdminGroupsController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  List<UnifiedGroup> unifiedGroups = [];
  List<EmployeeModel> employees = [];
  bool isLoading = true;
  String? errorMessage;

  AdminModel? currentAdmin;
  String _orgName = '';

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

      final doc =
          await _firebase.firestore.collection('users').doc(user.uid).get();

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

      await Future.wait([
        _loadOrgName(orgId),
        _loadEmployees(orgId),
      ]);

      _listenToProjectGroups(orgId);
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOrgName(String orgId) async {
    try {
      final snap =
          await _firebase.firestore.collection('organizations').doc(orgId).get();
      _orgName =
          (snap.data()?['name'] as String?)?.trim().isNotEmpty == true
              ? snap.data()!['name'] as String
              : 'Company';
    } catch (_) {
      _orgName = 'Company';
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

  void _listenToProjectGroups(String orgId) {
    _groupsSub?.cancel();
    _groupsSub = _firebase.firestore
        .collection('projectGroups')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final projectGroups = snapshot.docs
                .map((doc) =>
                    ProjectGroupModel.fromJson(doc.data(), id: doc.id))
                .toList();
            _rebuild(orgId, projectGroups);
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

  void _rebuild(String orgId, List<ProjectGroupModel> projectGroups) {
    final result = <UnifiedGroup>[];

    // 1. Company-wide group
    result.add(UnifiedGroup(
      id: 'org_general',
      name: _orgName,
      type: 'company',
      messagesPath: 'organizations/$orgId/org_chats/general/messages',
      isDeletable: false,
      memberCount: employees.length,
    ));

    // 2. Department groups — one per unique department
    final seen = <String>{};
    for (final emp in employees) {
      final deptId = _normalizeDeptId(emp);
      if (seen.contains(deptId)) continue;
      seen.add(deptId);
      result.add(UnifiedGroup(
        id: 'dept_$deptId',
        name: emp.department.isNotEmpty ? emp.department : deptId,
        type: 'department',
        messagesPath:
            'organizations/$orgId/departments/$deptId/messages',
        isDeletable: false,
        memberCount: employees
            .where((e) => _normalizeDeptId(e) == deptId)
            .length,
      ));
    }

    // 3. Project groups (admin-created, deletable)
    for (final pg in projectGroups) {
      result.add(UnifiedGroup(
        id: pg.id!,
        name: pg.name,
        type: 'project',
        messagesPath: 'projectGroups/${pg.id}/messages',
        isDeletable: true,
        memberCount: pg.memberIds.length,
      ));
    }

    unifiedGroups = result;
  }

  String _normalizeDeptId(EmployeeModel emp) {
    final id = emp.departmentId.trim();
    if (id.isNotEmpty) return _sanitize(id);
    final name = emp.department.trim();
    if (name.isNotEmpty) return _sanitize(name);
    return 'general';
  }

  String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();

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
      metadata: {'groupName': name.trim(), 'memberCount': memberIds.length},
    ).ignore();
  }

  Future<void> deleteGroup(UnifiedGroup group) async {
    if (!group.isDeletable) {
      throw Exception('cannotDeleteSystemGroup');
    }

    await _firebase.firestore
        .collection('projectGroups')
        .doc(group.id)
        .delete();

    LoggingService.instance.log(
      actionType: 'PROJECT_GROUP_DELETED',
      category: 'groups',
      descriptionKey: 'logProjectGroupDeleted',
      metadata: {'groupName': group.name},
    ).ignore();
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    super.dispose();
  }
}
