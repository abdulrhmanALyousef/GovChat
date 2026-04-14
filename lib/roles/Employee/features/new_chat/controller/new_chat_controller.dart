import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../models/employee_model.dart';

class NewChatController extends ChangeNotifier {
  NewChatController({required this.currentEmployee}) {
    _listenToEmployees();
  }

  final EmployeeModel currentEmployee;

  List<EmployeeModel> _allEmployees = [];
  List<EmployeeModel> filteredEmployees = [];

  bool isLoading = true;
  bool isCreating = false;
  String? errorMessage;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  void _listenToEmployees() {
    _subscription = FirebaseService.instance.firestore
        .collection('employees')
        .where('organizationId', isEqualTo: currentEmployee.organizationId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snapshot) {
            _allEmployees = snapshot.docs
                .map((doc) => EmployeeModel.fromJson(doc.data(), id: doc.id))
                .where((e) => e.id != currentEmployee.id)
                .toList();
            _allEmployees.sort((a, b) => a.name.compareTo(b.name));
            filteredEmployees = List<EmployeeModel>.from(_allEmployees);
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

  void onSearchChanged(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      filteredEmployees = List<EmployeeModel>.from(_allEmployees);
    } else {
      filteredEmployees = _allEmployees
          .where((e) => e.displayId.toLowerCase().contains(trimmed))
          .toList();
    }
    notifyListeners();
  }

  /// Creates (or locates) the private chat document and returns the chatId.
  /// Returns null on error.
  Future<String?> startPrivateChat(EmployeeModel other) async {
    isCreating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final myId = currentEmployee.id ?? '';
      final otherId = other.id ?? '';

      // Deterministic chat ID: sort both UIDs so both users share the same doc.
      final ids = [myId, otherId]..sort();
      final chatId = ids.join('_');

      final chatRef = FirebaseService.instance.firestore
          .collection('organizations')
          .doc(currentEmployee.organizationId)
          .collection('private_chats')
          .doc(chatId);

      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        await chatRef.set({
          'participants': [myId, otherId],
          'participantDisplayIds': {
            myId: currentEmployee.displayId,
            otherId: other.displayId,
          },
          'participantNames': {
            myId: currentEmployee.name,
            otherId: other.name,
          },
          'organizationId': currentEmployee.organizationId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      isCreating = false;
      notifyListeners();
      return chatId;
    } catch (e) {
      errorMessage = e.toString();
      isCreating = false;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}