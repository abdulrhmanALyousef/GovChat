import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';

class EmployeeResetPasswordController extends ChangeNotifier {
  EmployeeResetPasswordController({required this.uid}) {
    newPasswordController.addListener(notifyListeners);
  }

  final String uid;

  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;

  // Same password rules as the existing ChangePasswordController.
  bool get hasMinLength => newPasswordController.text.length >= 8;
  bool get hasUppercase =>
      newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get hasLowercase =>
      newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get hasNumber => newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get hasSpecialChar =>
      newPasswordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  Future<bool> updatePassword(BuildContext context) async {
    if (!formKey.currentState!.validate()) return false;

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

      // Update password in Firebase Auth.
      await user.updatePassword(newPasswordController.text.trim());

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
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
