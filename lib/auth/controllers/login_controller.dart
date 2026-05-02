import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import '../../core/datasource/local_data/preferences_manager.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/services/activity_log_service.dart';
import '../../core/services/session_manager.dart';
import '../../models/admin_model.dart';
import '../../models/employee_model.dart';
import '../../roles/Admin/features/Main/admin_main_screen.dart';
import '../../roles/employee/features/main/employee_main_screen.dart';
import '../../roles/primary Admin/Features/Main/main_screen.dart';
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

    final l = AppLocalizations.of(context)!;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Sign in
      final credential = await FirebaseService.instance.auth
          .signInWithEmailAndPassword(
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

      // 3. Enforce account status + role-specific checks
      final status = doc.data()!['status'] ?? 'active';
      if (user.role == 'employee') {
        if (status == 'pending') {
          await FirebaseService.instance.auth.signOut();
          errorMessage = l.accountPendingApproval;
          isLoading = false;
          notifyListeners();
          return;
        }
        if (status == 'rejected') {
          await FirebaseService.instance.auth.signOut();
          errorMessage = l.accessRequestRejected;
          isLoading = false;
          notifyListeners();
          return;
        }
      } else if (status != 'active') {
        await FirebaseService.instance.auth.signOut();
        errorMessage = l.accountIsStatus(status);
        isLoading = false;
        notifyListeners();
        return;
      }

      // 4. Save user data in SharedPreferences
      final prefs = PreferencesManager();
      await prefs.setString('uid', user.uid);
      await prefs.setString('email', user.email);
      await prefs.setString('role', user.role);
      await prefs.setBool('firstLogin', user.firstLogin);
      await prefs.setBool('mustChangePassword', user.mustChangePassword);
      if (user.organizationId != null) {
        await prefs.setString('organizationId', user.organizationId!);
      }
      if (user.organizationName != null) {
        await prefs.setString('organizationName', user.organizationName!);
      }

      // 5. Enforce password rotation for admins
      if (!context.mounted) return;
      final mustRotatePassword = user.firstLogin || user.mustChangePassword;
      if (user.role == 'admin' && mustRotatePassword) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          (route) => false,
        );
        return;
      }
      if (user.role == 'primary_admin' && user.mustChangePassword) {
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
        case 'employee':
          final employee = await _loadEmployeeProfile(uid, doc.data()!);
          if (!context.mounted) return;
          final orgId = user.organizationId ?? '';
          if (orgId.isNotEmpty && employee.organizationId != orgId) {
            await SessionManager.instance.logout(
              context,
              reason: l.organizationMismatchSignIn,
            );
            return;
          }
          destination = EmployeeMainScreen(employee: employee);
          break;
        default:
          errorMessage = l.unknownRoleError(user.role);
          isLoading = false;
          notifyListeners();
          return;
      }

      // Track login activity (fire-and-forget — never block navigation)
      ActivityLogService.instance.log(
        action: ActivityLogService.actionLogin,
        actorId: uid,
        actorEmail: user.email,
        actorRole: user.role,
        organizationId: user.organizationId,
      );
      ActivityLogService.instance.updateLoginActivity();

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      errorMessage = _mapAuthError(e.code, l);
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<EmployeeModel> _loadEmployeeProfile(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    try {
      final empDoc = await FirebaseService.instance.firestore
          .collection('employees')
          .doc(uid)
          .get();

      if (empDoc.exists) {
        final employee = EmployeeModel.fromJson(empDoc.data()!, id: uid);
        final deptId = employee.departmentId.trim().isNotEmpty
            ? employee.departmentId.trim()
            : _slugDepartment(employee.department);

        if (employee.departmentId.isEmpty) {
          await FirebaseService.instance.firestore
              .collection('employees')
              .doc(uid)
              .update({'departmentId': deptId});
        }

        return EmployeeModel(
          id: employee.id,
          name: employee.name,
          email: employee.email,
          nationalId: employee.nationalId,
          organizationId: employee.organizationId,
          organizationName: employee.organizationName,
          department: employee.department,
          departmentId: deptId,
          displayId: employee.displayId.isNotEmpty
              ? employee.displayId
              : 'EMP-${uid.substring(0, 5).toUpperCase()}',
          status: employee.status,
          createdAt: employee.createdAt,
        );
      }
    } catch (_) {}

    final deptId = _slugDepartment(userData['department'] ?? '');
    return EmployeeModel(
      id: uid,
      name: userData['name'] ?? '',
      email: userData['email'] ?? '',
      nationalId: userData['nationalId'] ?? '',
      organizationId: userData['organizationId'] ?? '',
      organizationName: userData['organizationName'] ?? '',
      department: userData['department'] ?? '',
      departmentId: deptId,
      displayId:
          userData['displayId'] ?? 'EMP-${uid.substring(0, 5).toUpperCase()}',
      status: userData['status'] ?? 'active',
      createdAt: null,
    );
  }

  String _slugDepartment(String value) {
    if (value.trim().isEmpty) return 'general';
    return value.trim().replaceAll(' ', '_').toLowerCase();
  }

  String _mapAuthError(String code, AppLocalizations l) {
    switch (code) {
      case 'user-not-found':
        return l.authErrorUserNotFound;
      case 'wrong-password':
        return l.authErrorWrongPassword;
      case 'invalid-email':
        return l.authErrorInvalidEmail;
      case 'user-disabled':
        return l.authErrorUserDisabled;
      case 'invalid-credential':
        return l.authErrorInvalidCredential;
      case 'too-many-requests':
        return l.authErrorTooManyRequests;
      default:
        return l.authErrorDefault;
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
