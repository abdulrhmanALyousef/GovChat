import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/admin_model.dart';
import '../../../../../models/employee_model.dart';

class EmployeesController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  List<EmployeeModel> employees = [];
  bool isLoading = true;
  String? errorMessage;

  AdminModel? currentAdmin;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

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
    employees = snapshot.docs
        .map((doc) => EmployeeModel.fromJson(doc.data(), id: doc.id))
        .toList();

    employees.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    debugPrint('Fetched employees: ${employees.length}');
    errorMessage = null;
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
