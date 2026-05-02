import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../../core/services/activity_log_service.dart';
import '../../../../../../models/employee_model.dart';
import '../../../../../../models/organization_model.dart';

class OrganizationsManagementController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;
  bool _isDisposed = false;

  List<OrganizationModel> organizations = <OrganizationModel>[];
  bool isLoading = true;
  String? errorMessage;
  String? successMessage;

  bool isProcessingOrganization = false;
  bool isProcessingEmployee = false;

  OrganizationsManagementController() {
    loadOrganizations();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> loadOrganizations() async {
    isLoading = true;
    errorMessage = null;
    _safeNotifyListeners();

    try {
      final snapshot = await _firebase.firestore
          .collection('organizations')
          .get();
      organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromJson(doc.data(), id: doc.id))
          .where((organization) => organization.status != 'deleted')
          .toList();

      organizations.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    } catch (e) {
      errorMessage = 'Failed to load organizations: $e';
    }

    isLoading = false;
    _safeNotifyListeners();
  }

  Future<List<EmployeeModel>> loadOrganizationEmployees(
    String organizationId,
  ) async {
    final snapshot = await _firebase.firestore
        .collection('employees')
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: 'employee')
        .get();

    final employees = snapshot.docs
        .map((doc) => EmployeeModel.fromJson(doc.data(), id: doc.id))
        .where((employee) => employee.status != 'deleted')
        .toList();

    employees.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return employees;
  }

  Future<EmployeeModel?> loadEmployeeDetails(
    String employeeId, {
    EmployeeModel? fallback,
  }) async {
    if (employeeId.trim().isEmpty) return fallback;

    try {
      final employeeDoc = await _firebase.firestore
          .collection('employees')
          .doc(employeeId)
          .get();
      final userDoc = await _firebase.firestore
          .collection('users')
          .doc(employeeId)
          .get();

      final employeeData = employeeDoc.data() ?? <String, dynamic>{};
      final userData = userDoc.data() ?? <String, dynamic>{};

      String pickString(List<dynamic> values) {
        for (final value in values) {
          final text = (value ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
        return '';
      }

      final merged = <String, dynamic>{...userData, ...employeeData};

      merged['name'] = pickString([
        employeeData['name'],
        userData['name'],
        userData['fullName'],
        fallback?.name,
      ]);

      merged['email'] = pickString([
        employeeData['email'],
        userData['email'],
        fallback?.email,
      ]);

      merged['nationalId'] = pickString([
        employeeData['nationalId'],
        userData['nationalId'],
        fallback?.nationalId,
      ]);

      merged['organizationId'] = pickString([
        employeeData['organizationId'],
        userData['organizationId'],
        fallback?.organizationId,
      ]);

      merged['organizationName'] = pickString([
        employeeData['organizationName'],
        userData['organizationName'],
        fallback?.organizationName,
      ]);

      merged['department'] = pickString([
        employeeData['department'],
        userData['department'],
        fallback?.department,
      ]);

      merged['departmentId'] = pickString([
        employeeData['departmentId'],
        userData['departmentId'],
        fallback?.departmentId,
      ]);

      merged['displayId'] = pickString([
        employeeData['displayId'],
        userData['displayId'],
        fallback?.displayId,
      ]);

      merged['status'] = pickString([
        employeeData['status'],
        userData['status'],
        fallback?.status,
      ]);

      return EmployeeModel.fromJson(merged, id: employeeId);
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> updateOrganization({
    required String organizationId,
    required String name,
    required String city,
    required String address,
    required String industry,
    required String employeeRange,
  }) async {
    isProcessingOrganization = true;
    errorMessage = null;
    successMessage = null;
    _safeNotifyListeners();

    try {
      await _firebase.firestore
          .collection('organizations')
          .doc(organizationId)
          .update({
            'name': name,
            'city': city,
            'address': address,
            'industry': industry,
            'employeeRange': employeeRange,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      successMessage = 'Organization updated successfully.';

      final actor = _firebase.auth.currentUser;
      if (actor != null) {
        ActivityLogService.instance.log(
          action: ActivityLogService.actionOrgUpdated,
          actorId: actor.uid,
          actorEmail: actor.email ?? '',
          actorRole: 'primary_admin',
          organizationId: organizationId,
          organizationName: name,
        );
      }

      await loadOrganizations();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update organization: $e';
      _safeNotifyListeners();
      return false;
    } finally {
      isProcessingOrganization = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> deleteOrganization(OrganizationModel organization) async {
    isProcessingOrganization = true;
    errorMessage = null;
    successMessage = null;
    _safeNotifyListeners();

    try {
      final firestore = _firebase.firestore;
      final orgId = organization.id;
      if (orgId == null || orgId.isEmpty) {
        errorMessage = 'Organization id is missing.';
        isProcessingOrganization = false;
        _safeNotifyListeners();
        return false;
      }

      await firestore.collection('organizations').doc(orgId).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });

      final employeesSnapshot = await firestore
          .collection('employees')
          .where('organizationId', isEqualTo: orgId)
          .get();

      for (final doc in employeesSnapshot.docs) {
        await doc.reference.update({
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }

      final usersSnapshot = await firestore
          .collection('users')
          .where('organizationId', isEqualTo: orgId)
          .get();

      for (final doc in usersSnapshot.docs) {
        await doc.reference.update({
          'status': 'deleted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final pendingRequestsSnapshot = await firestore
          .collection('accessRequests')
          .where('organizationId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingRequestsSnapshot.docs) {
        await doc.reference.update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      successMessage = 'Organization deleted safely.';

      final actor = _firebase.auth.currentUser;
      if (actor != null) {
        ActivityLogService.instance.log(
          action: ActivityLogService.actionOrgDeleted,
          actorId: actor.uid,
          actorEmail: actor.email ?? '',
          actorRole: 'primary_admin',
          organizationId: orgId,
          organizationName: organization.name,
        );
      }

      await loadOrganizations();
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete organization: $e';
      _safeNotifyListeners();
      return false;
    } finally {
      isProcessingOrganization = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> updateEmployee({
    required String employeeId,
    required String name,
    required String email,
    required String nationalId,
  }) async {
    isProcessingEmployee = true;
    errorMessage = null;
    successMessage = null;
    _safeNotifyListeners();

    try {
      final updates = <String, dynamic>{
        'name': name,
        'email': email,
        'nationalId': nationalId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firebase.firestore
          .collection('employees')
          .doc(employeeId)
          .update(updates);

      final userRef = _firebase.firestore.collection('users').doc(employeeId);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        await userRef.update(<String, dynamic>{
          'email': email,
          'fullName': name,
          'nationalId': nationalId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      successMessage = 'Employee updated successfully.';

      final actor = _firebase.auth.currentUser;
      if (actor != null) {
        ActivityLogService.instance.log(
          action: ActivityLogService.actionEmployeeUpdated,
          actorId: actor.uid,
          actorEmail: actor.email ?? '',
          actorRole: 'primary_admin',
          targetId: employeeId,
          targetEmail: email,
        );
      }

      _safeNotifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update employee: $e';
      _safeNotifyListeners();
      return false;
    } finally {
      isProcessingEmployee = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> deleteEmployee(EmployeeModel employee) async {
    isProcessingEmployee = true;
    errorMessage = null;
    successMessage = null;
    _safeNotifyListeners();

    try {
      final employeeId = employee.id;
      if (employeeId == null || employeeId.isEmpty) {
        errorMessage = 'Employee id is missing.';
        isProcessingEmployee = false;
        _safeNotifyListeners();
        return false;
      }

      await _firebase.firestore.collection('employees').doc(employeeId).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });

      final userRef = _firebase.firestore.collection('users').doc(employeeId);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        await userRef.update({
          'status': 'deleted',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final pendingRequests = await _firebase.firestore
          .collection('accessRequests')
          .where('uid', isEqualTo: employeeId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingRequests.docs) {
        await doc.reference.update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      successMessage = 'Employee removed safely.';

      final actor = _firebase.auth.currentUser;
      if (actor != null) {
        ActivityLogService.instance.log(
          action: ActivityLogService.actionEmployeeDeleted,
          actorId: actor.uid,
          actorEmail: actor.email ?? '',
          actorRole: 'primary_admin',
          targetId: employeeId,
          targetEmail: employee.email,
        );
      }

      _safeNotifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to delete employee: $e';
      _safeNotifyListeners();
      return false;
    } finally {
      isProcessingEmployee = false;
      _safeNotifyListeners();
    }
  }

  void clearMessages() {
    successMessage = null;
    errorMessage = null;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
