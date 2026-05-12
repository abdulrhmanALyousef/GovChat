import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import '../../core/datasource/local_data/preferences_manager.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/services/activity_log_service.dart';
import '../../core/services/encryption/e2ee_manager.dart';
import '../../core/services/logging_service.dart';
import '../../models/employee_model.dart';
import '../../roles/employee/features/main/employee_main_screen.dart';
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
      // 1. Firebase Auth sign-in
      final credential = await FirebaseService.instance.auth
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final uid = credential.user!.uid;

      // 2. Single authoritative check — employees collection only.
      //    Admin/primary_admin accounts have no employees doc so they are
      //    rejected immediately with the same generic error as a wrong
      //    password, preventing role/account-existence leakage.
      final empDoc = await FirebaseService.instance.firestore
          .collection('employees')
          .doc(uid)
          .get();

      if (!empDoc.exists) {
        await FirebaseService.instance.auth.signOut();
        errorMessage = l.authErrorInvalidCredential;
        isLoading = false;
        notifyListeners();
        return;
      }

      final rawData = empDoc.data()!;

      // Safety guard: only docs with role == 'employee' may proceed.
      // A missing role field is treated the same as a non-employee role —
      // no default assumed. This catches admin accounts that somehow have
      // an employees doc (missing or wrong role) and any corrupted data.
      final docRole = rawData['role'] as String?;
      if (docRole != 'employee') {
        await FirebaseService.instance.auth.signOut();
        errorMessage = l.authErrorInvalidCredential;
        isLoading = false;
        notifyListeners();
        return;
      }

      final employee = EmployeeModel.fromJson(rawData, id: uid);

      if (!context.mounted) return;

      // 3. Enforce account status
      switch (employee.status) {
        case 'pending':
          await FirebaseService.instance.auth.signOut();
          if (employee.organizationId.isNotEmpty) {
            LoggingService.instance
                .log(
                  organizationId: employee.organizationId,
                  actionType: 'login_failure',
                  descriptionKey: 'logLoginFailure',
                  performedByUserId: uid,
                  performedByRole: 'employee',
                  performedByEmail: employee.email,
                  performedByName: employee.name,
                  metadata: {'reason': 'account_pending'},
                )
                .ignore();
          }
          errorMessage = l.accountPendingApproval;
          isLoading = false;
          notifyListeners();
          return;

        case 'rejected':
          await FirebaseService.instance.auth.signOut();
          if (employee.organizationId.isNotEmpty) {
            LoggingService.instance
                .log(
                  organizationId: employee.organizationId,
                  actionType: 'login_failure',
                  descriptionKey: 'logLoginFailure',
                  performedByUserId: uid,
                  performedByRole: 'employee',
                  performedByEmail: employee.email,
                  performedByName: employee.name,
                  metadata: {'reason': 'account_rejected'},
                )
                .ignore();
          }
          errorMessage = l.accessRequestRejected;
          isLoading = false;
          notifyListeners();
          return;

        case 'active':
          break;

        default:
          await FirebaseService.instance.auth.signOut();
          errorMessage = l.accountIsStatus(employee.status);
          isLoading = false;
          notifyListeners();
          return;
      }

      // 4. Normalise departmentId (write-back is fire-and-forget)
      final deptId = employee.departmentId.trim().isNotEmpty
          ? employee.departmentId.trim()
          : _slugDepartment(employee.department);

      if (employee.departmentId.isEmpty) {
        FirebaseService.instance.firestore
            .collection('employees')
            .doc(uid)
            .update({'departmentId': deptId})
            .ignore();
      }

      final fullEmployee = EmployeeModel(
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
        avatarUrl: employee.avatarUrl,
      );

      // 5. Init E2EE keys — fire-and-forget, does not delay navigation
      E2eeManager.initializeKeys(uid).ignore();

      // 6. Persist session
      final prefs = PreferencesManager();
      await prefs.setString('uid', uid);
      await prefs.setString('email', fullEmployee.email);
      await prefs.setString('role', 'employee');
      await prefs.setString('organizationId', fullEmployee.organizationId);
      await prefs.setString('organizationName', fullEmployee.organizationName);

      // 7. Audit logs (fire-and-forget)
      if (fullEmployee.organizationId.isNotEmpty) {
        LoggingService.instance
            .log(
              organizationId: fullEmployee.organizationId,
              actionType: 'login_success',
              descriptionKey: 'logLoginSuccess',
              performedByUserId: uid,
              performedByRole: 'employee',
              performedByEmail: fullEmployee.email,
              performedByName: fullEmployee.name,
            )
            .ignore();
      }
      ActivityLogService.instance.log(
        actionType: ActivityLogService.actionLogin,
        userId: uid,
        email: fullEmployee.email,
        role: 'employee',
        organizationId: fullEmployee.organizationId,
      );

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeMainScreen(employee: fullEmployee),
        ),
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

  String _slugDepartment(String value) {
    if (value.trim().isEmpty) return 'general';
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
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
