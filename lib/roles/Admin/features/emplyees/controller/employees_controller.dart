import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/employee_model.dart';



class EmployeesController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  // ── Source of truth (never mutated outside _handleSnapshot) ──────────────────
  List<EmployeeModel> _allEmployees = [];

  // ── Displayed list (derived by _applyFilters) ─────────────────────────────────
  List<EmployeeModel> filteredEmployees = [];

  // ── Filter state ───────────────────────────────────────────────────────────────
  String searchQuery = '';
  String? selectedDepartment;

  bool isLoading = true;
  String? errorMessage;

  AdminModel? currentAdmin;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  // ── Public read-only access to the full list (used for empty-state checks) ────
  List<EmployeeModel> get employees => _allEmployees;

  // ── Unique sorted departments derived from the full list ──────────────────────
  List<String> get availableDepartments => _allEmployees
      .map((e) => e.department)
      .where((d) => d.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  EmployeesController() {
    _init();
  }

  Future<void> _init() async {
    await _loadAdminAndListen();
  }

  Future<void> _loadAdminAndListen() async {
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

      final adminDoc = await _firebase.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (!adminDoc.exists) {
        errorMessage = 'Admin data not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      currentAdmin = AdminModel.fromJson(adminDoc.data()!);
      final orgId = currentAdmin?.organizationId;

      debugPrint('Employees -> Admin Org ID: $orgId');

      if (orgId == null || orgId.isEmpty) {
        errorMessage = 'Organization not found for this admin account';
        isLoading = false;
        notifyListeners();
        return;
      }

      _subscription?.cancel();

      _subscription = _firebase.firestore
          .collection('employees')
          .where('organizationId', isEqualTo: orgId)
          .where('role', isEqualTo: 'employee')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen(
            _handleSnapshot,
            onError: (error) {
              errorMessage = error.toString();
              isLoading = false;
              notifyListeners();
            },
          );
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _allEmployees = snapshot.docs
        .map((doc) => EmployeeModel.fromJson(doc.data(), id: doc.id))
        .toList();

    _allEmployees.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    debugPrint('Fetched employees: ${_allEmployees.length}');
    for (final e in _allEmployees) {
      debugPrint('Employee loaded -> id: ${e.id}, name: "${e.name}", displayId: ${e.displayId}');
    }

    errorMessage = null;
    isLoading = false;
    _applyFilters(); // calls notifyListeners
  }

  // ─── Filter API ───────────────────────────────────────────────────────────────

  void setSearch(String query) {
    searchQuery = query;
    _applyFilters();
  }

  // Tapping the already-selected dept deselects it (acts as toggle).
  void setDepartment(String? dept) {
    selectedDepartment = (dept == selectedDepartment) ? null : dept;
    _applyFilters();
  }

  void _applyFilters() {
    List<EmployeeModel> temp = List.of(_allEmployees);

    if (selectedDepartment != null) {
      temp = temp
          .where((e) => e.department == selectedDepartment)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.displayId.toLowerCase().contains(q) ||
                e.email.toLowerCase().contains(q),
          )
          .toList();
    }

    filteredEmployees = temp;
    notifyListeners();
  }

  // ─── Fetch latest employee data for the edit form ───────────────────────────
  // Falls back to users/{uid} for nationalId because the approval flow does
  // not copy nationalId into the employees collection.
  Future<Map<String, String>> fetchEmployeeForEdit(String employeeId) async {
    final orgId = currentAdmin?.organizationId;
    if (orgId == null || orgId.isEmpty) throw Exception('Organization not found');

    final empDoc = await _firebase.firestore
        .collection('employees')
        .doc(employeeId)
        .get();
    if (!empDoc.exists) throw Exception('Employee not found');

    final empData = empDoc.data()!;
    if ((empData['organizationId'] ?? '') != orgId) {
      throw Exception('Access denied');
    }

    String nationalId = (empData['nationalId'] ?? '').toString();
    if (nationalId.isEmpty) {
      try {
        final userDoc = await _firebase.firestore
            .collection('users')
            .doc(employeeId)
            .get();
        if (userDoc.exists) {
          nationalId = (userDoc.data()?['nationalId'] ?? '').toString();
        }
      } catch (_) {}
    }

    return {
      'name': (empData['name'] ?? '').toString(),
      'department': (empData['department'] ?? '').toString(),
      'nationalId': nationalId,
    };
  }

  // ─── Update editable employee fields ─────────────────────────────────────────
  Future<void> updateEmployee(
    String employeeId, {
    required String name,
    required String department,
    required String nationalId,
  }) async {
    final orgId = currentAdmin?.organizationId;
    if (orgId == null || orgId.isEmpty) throw Exception('Organization not found');

    final empDoc = await _firebase.firestore
        .collection('employees')
        .doc(employeeId)
        .get();
    if (!empDoc.exists) throw Exception('Employee not found');
    if ((empDoc.data()?['organizationId'] ?? '') != orgId) {
      throw Exception('Access denied');
    }

    final trimmedDept = department.trim();
    final deptId = trimmedDept
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();

    final batch = _firebase.firestore.batch();

    batch.update(
      _firebase.firestore.collection('employees').doc(employeeId),
      {
        'name': name.trim(),
        'department': trimmedDept,
        'departmentId': deptId,
        'nationalId': nationalId.trim(),
      },
    );

    batch.update(
      _firebase.firestore.collection('users').doc(employeeId),
      {
        'name': name.trim(),
        'fullName': name.trim(),
        'nationalId': nationalId.trim(),
      },
    );

    await batch.commit();

    // Log the update (fire-and-forget)
    final adminUser = _firebase.currentUser;
    if (adminUser != null && orgId.isNotEmpty) {
      LoggingService.instance.log(
        organizationId: orgId,
        actionType: 'employee_updated',
        descriptionKey: 'logEmployeeUpdated',
        performedByUserId: adminUser.uid,
        performedByRole: 'admin',
        performedByName: currentAdmin?.email,
        targetId: employeeId,
        metadata: {'updatedName': name.trim(), 'updatedDepartment': trimmedDept},
      );
    }
  }

  // ─── Soft-delete: set status → inactive in employees + users ─────────────────
  // Prevents login (SessionManager.ensureRole rejects non-active status) and
  // removes the employee from the active list without destroying audit data.
  Future<void> deleteEmployee(String employeeId) async {
    final orgId = currentAdmin?.organizationId;
    if (orgId == null || orgId.isEmpty) throw Exception('Organization not found');

    final empDoc = await _firebase.firestore
        .collection('employees')
        .doc(employeeId)
        .get();
    if (!empDoc.exists) throw Exception('Employee not found or already removed');
    if ((empDoc.data()?['organizationId'] ?? '') != orgId) {
      throw Exception('Access denied');
    }

    final batch = _firebase.firestore.batch();

    batch.update(
      _firebase.firestore.collection('employees').doc(employeeId),
      {'status': 'inactive'},
    );

    batch.update(
      _firebase.firestore.collection('users').doc(employeeId),
      {'status': 'inactive'},
    );

    await batch.commit();

    // Log the deactivation (fire-and-forget)
    final adminUser = _firebase.currentUser;
    if (adminUser != null && orgId.isNotEmpty) {
      LoggingService.instance.log(
        organizationId: orgId,
        actionType: 'employee_deleted',
        descriptionKey: 'logEmployeeDeleted',
        performedByUserId: adminUser.uid,
        performedByRole: 'admin',
        performedByName: currentAdmin?.email,
        targetId: employeeId,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
