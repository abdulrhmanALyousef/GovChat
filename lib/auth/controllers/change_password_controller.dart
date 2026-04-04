import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/datasource/local_data/preferences_manager.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../models/admin_model.dart';
import '../../roles/Admin/features/Main/admin_main_screen.dart';
import '../../roles/primary Admin/Features/Main/main_screen.dart';

class ChangePasswordController extends ChangeNotifier {
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
  bool get hasSpecialChar =>
      newPasswordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  ChangePasswordController() {
    newPasswordController.addListener(notifyListeners);
  }

  Future<void> updatePassword(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseService.instance.auth.currentUser;
      if (user == null) {
        errorMessage = 'User not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      // 1. Update password in Firebase Auth
      await user.updatePassword(newPasswordController.text.trim());

      // 2. Update firstLogin and mustChangePassword in Firestore
      await FirebaseService.instance.firestore
          .collection('users')
          .doc(user.uid)
          .update({'firstLogin': false, 'mustChangePassword': false});

      // 3. Update SharedPreferences
      final prefs = PreferencesManager();
      await prefs.setBool('firstLogin', false);

      // 4. Get role and navigate user
      final doc = await FirebaseService.instance.firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!context.mounted) return;

      if (!doc.exists) {
        errorMessage = 'User data not found';
        isLoading = false;
        notifyListeners();
        return;
      }

      final userData = AdminModel.fromJson(doc.data()!);

      Widget destination;
      switch (userData.role) {
        case 'admin':
          destination = const AdminMainScreen();
          break;
        case 'primary_admin':
          destination = const MainScreen();
          break;
        default:
          errorMessage = 'Unknown role';
          isLoading = false;
          notifyListeners();
          return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'Failed to update password';
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
