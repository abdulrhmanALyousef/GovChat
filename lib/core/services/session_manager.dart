import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../auth/login_screen.dart';
import '../datasource/local_data/preferences_manager.dart';
import '../datasource/remote_data/firebase_service.dart';
import 'encryption/e2ee_manager.dart';
import 'logging_service.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final PreferencesManager _preferences = PreferencesManager();

  Future<void> logout(BuildContext context, {String? reason}) async {
    final l = AppLocalizations.of(context);
    String? error;

    // Log logout before clearing session data
    final user = FirebaseService.instance.currentUser;
    if (user != null) {
      final orgId = _preferences.getString('organizationId') ?? '';
      final isInactivity = reason != null &&
          (reason.contains('inactivity') || reason.contains('عدم النشاط'));
      if (orgId.isNotEmpty) {
        LoggingService.instance.log(
          organizationId: orgId,
          actionType: isInactivity ? 'auto_logout_inactivity' : 'logout',
          descriptionKey:
              isInactivity ? 'logAutoLogoutInactivity' : 'logLogout',
          performedByUserId: user.uid,
          performedByRole: 'employee',
          performedByEmail: user.email ?? '',
          performedByName: user.email,
        );
      }
    }

    try {
      await FirebaseService.instance.auth.signOut();
    } catch (_) {
      error = l?.failedToSignOut ??
          'Failed to sign out. Check your connection and try again.';
    }

    await _preferences.clear();
    E2eeManager.clearCache();

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

  /// Validates the current Firebase user against the employees collection.
  /// The mobile app is employee-only — presence of an active employees/{uid}
  /// document is the sole authorization check.
  Future<bool> ensureRole(
    BuildContext context, {
    required List<String> allowedRoles,
    String? expectedOrganizationId,
  }) async {
    final l = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!context.mounted) return false;
      await logout(
        context,
        reason: l?.sessionExpired ?? 'Session expired. Please sign in again.',
      );
      return false;
    }

    // Mobile app is employee-only. Validate ONLY from employees collection.
    final empDoc = await FirebaseService.instance.firestore
        .collection('employees')
        .doc(user.uid)
        .get();

    if (!context.mounted) return false;

    final data = empDoc.data();
    if (data == null) {
      await logout(context, reason: l?.accountDataMissing ?? 'Account data missing. Please sign in.');
      return false;
    }

    final role = (data['role'] ?? '') as String;
    if (!allowedRoles.contains(role)) {
      if (!context.mounted) return false;
      await logout(context, reason: l?.unauthorizedAccess ?? 'Unauthorized access.');
      return false;
    }

    // Normalise 'approved' → 'active' written during the transition period.
    String status = (data['status'] ?? 'active') as String;
    if (status == 'approved') {
      status = 'active';
      FirebaseService.instance.firestore
          .collection('employees')
          .doc(user.uid)
          .update({'status': 'active'})
          .ignore();
    }

    if (status != 'active') {
      if (!context.mounted) return false;
      await logout(
        context,
        reason: l?.accountStatusMessage(status) ?? 'Account is $status.',
      );
      return false;
    }

    // phoneVerified must be true — set during access-request OTP flow.
    // Defaults to true for legacy records that pre-date the field (run
    // migrateEmployees Cloud Function to backfill those docs).
    final phoneVerified = (data['phoneVerified'] ?? true) as bool;
    if (!phoneVerified) {
      if (!context.mounted) return false;
      await logout(context, reason: l?.employeePhoneRequired ?? 'Phone verification required.');
      return false;
    }

    if (expectedOrganizationId != null && expectedOrganizationId.isNotEmpty) {
      final orgId = (data['organizationId'] ?? '') as String;
      if (orgId != expectedOrganizationId) {
        if (!context.mounted) return false;
        await logout(
          context,
          reason: l?.organizationMismatchDetected ??
              'Organization mismatch detected.',
        );
        return false;
      }
    }

    return true;
  }
}
