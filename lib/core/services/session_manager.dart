import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/login_screen.dart';
import '../datasource/local_data/preferences_manager.dart';
import '../datasource/remote_data/firebase_service.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final PreferencesManager _preferences = PreferencesManager();

  Future<void> logout(BuildContext context, {String? reason}) async {
    String? error;

    try {
      await FirebaseService.instance.auth.signOut();
    } catch (_) {
      error = 'Failed to sign out. Check your connection and try again.';
    }

    await _preferences.clear();

    if (!context.mounted) return;

    final message = reason ?? error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> ensureRole(
    BuildContext context, {
    required List<String> allowedRoles,
    String? expectedOrganizationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!context.mounted) return false;
      await logout(context, reason: 'Session expired. Please sign in again.');
      return false;
    }

    final doc = await FirebaseService.instance.firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!context.mounted) return false;

    final data = doc.data();
    if (data == null) {
      if (!context.mounted) return false;
      await logout(context, reason: 'Account data missing. Please sign in.');
      return false;
    }

    final role = (data['role'] ?? '') as String;
    if (!allowedRoles.contains(role)) {
      if (!context.mounted) return false;
      await logout(context, reason: 'Unauthorized access.');
      return false;
    }

    final status = (data['status'] ?? 'active') as String;
    if (status != 'active') {
      if (!context.mounted) return false;
      await logout(context, reason: 'Account is $status.');
      return false;
    }

    if (expectedOrganizationId != null && expectedOrganizationId.isNotEmpty) {
      final orgId = (data['organizationId'] ?? '') as String;
      if (orgId != expectedOrganizationId) {
        if (!context.mounted) return false;
        await logout(context, reason: 'Organization mismatch detected.');
        return false;
      }
    }

    return true;
  }
}
