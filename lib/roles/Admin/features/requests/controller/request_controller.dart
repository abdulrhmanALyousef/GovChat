import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/access_request_model.dart';
import '../../../../../models/admin_model.dart';

class RequestController extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService.instance;

  List<AccessRequestModel> requests = [];
  bool isLoading = true;
  String? errorMessage;

  final Set<String> _processingIds = {};
  AdminModel? currentAdmin;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  RequestController() {
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

      debugPrint('Admin Org ID: $orgId');

      if (orgId == null || orgId.isEmpty) {
        errorMessage = 'Organization not found for this admin account';
        isLoading = false;
        notifyListeners();
        return;
      }

      _subscription?.cancel();

      _subscription = _firebase.firestore
          .collection('accessRequests')
          .where('organizationId', isEqualTo: orgId)
          .where('status', isEqualTo: 'pending')
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
    requests = snapshot.docs
        .map((doc) => AccessRequestModel.fromJson(doc.data(), id: doc.id))
        .toList();
    requests.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    errorMessage = null;
    debugPrint('Fetched requests: ${requests.length}');
    isLoading = false;
    notifyListeners();
  }

  bool isProcessing(String requestId) => _processingIds.contains(requestId);

  Future<void> approveRequest(
    BuildContext context,
    AccessRequestModel request,
  ) async {
    final requestKey = _getRequestKey(request);
    errorMessage = null;
    _processingIds.add(requestKey);
    notifyListeners();

    try {
      final firestore = _firebase.firestore;
      final batch = firestore.batch();

      final employeeRef = request.uid != null
          ? firestore.collection('employees').doc(request.uid)
          : firestore.collection('employees').doc();
      final displayId =
          'EMP-${(request.uid ?? employeeRef.id).substring(0, 5).toUpperCase()}';
      batch.set(employeeRef, {
        'uid': request.uid ?? employeeRef.id,
        'email': request.email,
        'name': request.displayName,
        'organizationId': request.organizationId,
        'organizationName': request.organizationName,
        'departmentId': request.departmentId ?? request.department,
        'department': request.department,
        'displayId': displayId,
        'role': 'employee',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (request.uid != null) {
        final userRef = firestore.collection('users').doc(request.uid);
        batch.update(userRef, {
          'status': 'active',
          'role': 'employee',
          'fullName': request.displayName,
          'displayId': displayId,
        });
      }

      if (request.id != null) {
        final requestRef = firestore
            .collection('accessRequests')
            .doc(request.id);
        batch.update(requestRef, {
          'status': 'approved',
          'displayId': displayId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _sendApprovalEmail(request);

      debugPrint('Approved request: $requestKey');

      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.requestApproved)));
      }
    } catch (e) {
      errorMessage = e.toString();
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.failedToApproveRequest}: $e')),
        );
      }
    }

    _processingIds.remove(requestKey);
    notifyListeners();
  }

  Future<void> rejectRequest(
    BuildContext context,
    AccessRequestModel request,
  ) async {
    final requestKey = _getRequestKey(request);
    errorMessage = null;
    _processingIds.add(requestKey);
    notifyListeners();

    try {
      final firestore = _firebase.firestore;
      final batch = firestore.batch();

      if (request.uid != null) {
        final userRef = firestore.collection('users').doc(request.uid);
        batch.update(userRef, {'status': 'rejected'});
      }

      if (request.id != null) {
        final requestRef = firestore
            .collection('accessRequests')
            .doc(request.id);
        batch.update(requestRef, {
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.requestRejected)));
      }
    } catch (e) {
      errorMessage = e.toString();
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l.failedToRejectRequest}: $e')));
      }
    }

    _processingIds.remove(requestKey);
    notifyListeners();
  }

  Future<void> _sendApprovalEmail(AccessRequestModel request) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('sendAccessApprovedEmail');

      debugPrint('Sending approval email...');

      final result = await callable.call({
        'email': request.email,
        'name': request.displayName,
      });

      debugPrint('Email sent successfully: ${result.data}');
    } catch (e) {
      debugPrint('Approval email failed: $e');
    }
  }

  String _getRequestKey(AccessRequestModel request) {
    return request.id ?? request.uid ?? request.email;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
