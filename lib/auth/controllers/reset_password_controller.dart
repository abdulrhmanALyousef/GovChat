import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../core/services/activity_log_service.dart';
import '../../core/services/logging_service.dart';

class ResetPasswordController extends ChangeNotifier {
  ResetPasswordController({
    required this.uid,
    required this.organizationId,
    required this.email,
  }) {
    newPasswordController.addListener(notifyListeners);
  }

  final String uid;
  final String organizationId;
  final String email;

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
      .contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]'));

  /// Calls the [resetPasswordWithOtp] Cloud Function.
  /// Requires that verifyOtp already stamped [lastOtpVerificationAt] within
  /// the last 10 minutes for this uid.
  Future<bool> resetPassword(BuildContext context) async {
    if (!formKey.currentState!.validate()) return false;

    final l = AppLocalizations.of(context)!;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('resetPasswordWithOtp');

      final result = await callable.call({
        'uid': uid,
        'newPassword': newPasswordController.text.trim(),
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] != true) {
        errorMessage = data['message'] as String? ?? l.failedToUpdatePassword;
        isLoading = false;
        notifyListeners();
        return false;
      }

      // Audit logs — fire-and-forget
      if (organizationId.isNotEmpty) {
        LoggingService.instance
            .log(
              organizationId: organizationId,
              actionType: 'password_reset_completed',
              descriptionKey: 'logPasswordResetViaSms',
              performedByUserId: uid,
              performedByRole: 'employee',
              performedByEmail: email,
              performedByName: '',
            )
            .ignore();
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
    } on FirebaseFunctionsException catch (e) {
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
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
