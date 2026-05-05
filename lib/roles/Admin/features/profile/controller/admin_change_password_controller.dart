import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/logging_service.dart';

class AdminChangePasswordController extends ChangeNotifier {
  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;
  bool success = false;

  bool hasMinLength = false;
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;

  void onNewPasswordChanged(String val) {
    hasMinLength = val.length >= 8;
    hasUppercase = val.contains(RegExp(r'[A-Z]'));
    hasLowercase = val.contains(RegExp(r'[a-z]'));
    hasNumber = val.contains(RegExp(r'[0-9]'));
    hasSpecialChar = val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    notifyListeners();
  }

  bool get isPasswordStrong =>
      hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

  Future<void> changePassword() async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    errorMessage = null;
    success = false;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        errorMessage = 'User not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPasswordCtrl.text);

      final userDoc = await FirebaseService.instance.firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final orgId = (userDoc.data()?['organizationId'] as String?) ?? '';

      LoggingService.instance.log(
        organizationId: orgId,
        actionType: 'password_changed',
        descriptionKey: 'logPasswordChanged',
        performedByUserId: user.uid,
        performedByRole: 'admin',
        performedByEmail: user.email ?? '',
      ).ignore();

      success = true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'wrongCurrentPassword';
      } else {
        errorMessage = e.message ?? 'Failed to change password';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }
}
