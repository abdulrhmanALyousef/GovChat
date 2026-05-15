import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../../core/datasource/local_data/preferences_manager.dart';
import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/activity_log_service.dart';
import '../../../../../core/services/logging_service.dart';
import '../../../../../core/services/otp_service.dart';

class EmployeeResetPasswordController extends ChangeNotifier {
  EmployeeResetPasswordController({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.phoneVerified,
  }) {
    newPasswordController.addListener(notifyListeners);
  }

  final String uid;
  final String email;
  final String phoneNumber;
  final bool phoneVerified;

  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;

  bool get hasMinLength => newPasswordController.text.length >= 8;
  bool get hasUppercase =>
      newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get hasLowercase =>
      newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get hasNumber => newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get hasSpecialChar => newPasswordController.text
      .contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  /// Step 1 — Validate form, gate legacy employees, reauthenticate, send OTP.
  /// Returns true when OTP has been dispatched and the caller should push
  /// OtpVerificationScreen.
  Future<bool> prepareOtp(BuildContext context) async {
    if (!formKey.currentState!.validate()) return false;

    final l = AppLocalizations.of(context)!;

    // Legacy employee — no verified phone on record.
    if (phoneNumber.isEmpty || !phoneVerified) {
      errorMessage = l.cpNoPhoneMessage;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    // Reauthenticate with current password so updatePassword never fails
    // with requires-recent-login.
    try {
      final user = FirebaseService.instance.auth.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      errorMessage =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
              ? l.authErrorWrongPassword
              : (e.message ?? l.authErrorDefault);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }

    // Send OTP to the employee's verified phone number.
    try {
      await OtpService.instance.sendOtp(
        phone: phoneNumber,
        purpose: 'password_reset',
      );
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return false;
    }

    final orgId = PreferencesManager().getString('organizationId') ?? '';
    if (orgId.isNotEmpty) {
      LoggingService.instance.log(
        organizationId: orgId,
        actionType: 'password_change_otp_sent',
        descriptionKey: 'logPasswordChangeOtpSent',
        performedByUserId: uid,
        performedByRole: 'employee',
        performedByEmail: email,
        performedByName: '',
      );
    }

    isLoading = false;
    notifyListeners();
    return true;
  }

  /// Step 2 — Update Firebase Auth password after successful OTP verification.
  Future<bool> finalizeUpdate(BuildContext context) async {
    final l = AppLocalizations.of(context)!;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseService.instance.auth.currentUser;
      if (user == null) {
        errorMessage = l.userNotFound;
        isLoading = false;
        notifyListeners();
        return false;
      }

      await user.updatePassword(newPasswordController.text.trim());

      final orgId = PreferencesManager().getString('organizationId') ?? '';
      if (orgId.isNotEmpty) {
        LoggingService.instance.log(
          organizationId: orgId,
          actionType: 'password_changed',
          descriptionKey: 'logPasswordChanged',
          performedByUserId: uid,
          performedByRole: 'employee',
          performedByEmail: email,
          performedByName: '',
        );
      }

      ActivityLogService.instance.log(
        actionType: ActivityLogService.actionPasswordChanged,
        userId: uid,
        email: email,
        role: 'employee',
      );

      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? l.failedToUpdatePassword;
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
