import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/datasource/local_data/preferences_manager.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../models/admin_model.dart';
import '../../roles/Admin/features/Main/admin_main_screen.dart';
import '../../roles/primary Admin/Features/Main/Main_screen.dart';
import '../change_password_screen.dart';
import '../request_access_screen.dart';

class LoginController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;

  Future<void> login(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Sign in
      final credential =
          await FirebaseService.instance.auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      // 2. Get user data from Firestore
      final doc = await FirebaseService.instance.firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        // No document found -> create one (primary_admin)
        await FirebaseService.instance.firestore
            .collection('users')
            .doc(uid)
            .set({
          'uid': uid,
          'email': credential.user!.email,
          'role': 'primary_admin',
          'firstLogin': false,
          'mustChangePassword': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!context.mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        return;
      }

      final user = AdminModel.fromJson(doc.data()!);

      if (!context.mounted) return;

      // 3. If employee and status is pending -> block login
      if (user.role == 'employee') {
        final status = doc.data()!['status'] ?? 'pending';
        if (status == 'pending') {
          await FirebaseService.instance.auth.signOut();
          errorMessage = 'Your account is pending approval. Please wait for admin confirmation.';
          isLoading = false;
          notifyListeners();
          return;
        }
        if (status == 'rejected') {
          await FirebaseService.instance.auth.signOut();
          errorMessage = 'Your access request has been rejected.';
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      // 4. Save user data in SharedPreferences
      final prefs = PreferencesManager();
      await prefs.setString('uid', user.uid);
      await prefs.setString('email', user.email);
      await prefs.setString('role', user.role);
      await prefs.setBool('firstLogin', user.firstLogin);

      // 5. If admin and first login -> change password screen
      if (user.role == 'admin' && user.firstLogin) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          (route) => false,
        );
        return;
      }

      // 6. Navigate based on role
      Widget destination;
      switch (user.role) {
        case 'admin':
          destination = const AdminMainScreen();
          break;
        case 'primary_admin':
          destination = const MainScreen();
          break;
        default:
          errorMessage = 'Unknown role: ${user.role}';
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
      errorMessage = _mapAuthError(e.code);
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Login failed. Please try again';
    }
  }

  void requestAccess(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RequestAccessScreen()),
    );
  }

  void forgotPassword() {
    // TODO: navigate to forgot password screen
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}