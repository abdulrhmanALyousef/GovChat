import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import '../../core/datasource/local_data/preferences_manager.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/services/activity_log_service.dart';
import '../../core/services/encryption/e2ee_backup_service.dart';
import '../../core/services/encryption/e2ee_key_store.dart';
import '../../core/services/encryption/e2ee_manager.dart';
import '../../core/services/logging_service.dart';
import '../../core/services/otp_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/session_manager.dart';
import '../../core/Widgets/e2ee_backup_dialogs.dart';
import '../../models/employee_model.dart';
import '../../roles/employee/features/main/employee_main_screen.dart';
import '../otp_verification_screen.dart';
import '../forgot_password_screen.dart';
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

      // 2. Mobile is employee-only — validate from employees collection only.
      //    Admin/primary_admin accounts have no employees doc so they get a
      //    generic invalid-credential error, preventing role/account leakage.
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

      final empData = empDoc.data()!;

      // Safety guard: only docs with role == 'employee' may proceed.
      final docRole = empData['role'] as String?;
      if (docRole != 'employee') {
        await FirebaseService.instance.auth.signOut();
        errorMessage = l.authErrorInvalidCredential;
        isLoading = false;
        notifyListeners();
        return;
      }

      final empOrgId = empData['organizationId'] as String? ?? '';

      // 3. Enforce account status
      final empStatus = empData['status'] as String? ?? 'pending';
      switch (empStatus) {
        case 'pending':
          await FirebaseService.instance.auth.signOut();
          if (empOrgId.isNotEmpty) {
            LoggingService.instance
                .log(
                  organizationId: empOrgId,
                  actionType: 'login_failure',
                  performedByUserId: uid,
                  performedByRole: 'employee',
                  performedByEmail: empData['email'] as String? ?? '',
                  performedByName: empData['name'] as String? ?? '',
                  performedByEmployeeId: empData['displayId'] as String? ?? '',
                  metadata: {'reason': 'account_pending', 'status': 'pending'},
                )
                .ignore();
          }
          errorMessage = l.accountPendingApproval;
          isLoading = false;
          notifyListeners();
          return;

        case 'rejected':
          await FirebaseService.instance.auth.signOut();
          if (empOrgId.isNotEmpty) {
            LoggingService.instance
                .log(
                  organizationId: empOrgId,
                  actionType: 'login_failure',
                  performedByUserId: uid,
                  performedByRole: 'employee',
                  performedByEmail: empData['email'] as String? ?? '',
                  performedByName: empData['name'] as String? ?? '',
                  performedByEmployeeId: empData['displayId'] as String? ?? '',
                  metadata: {'reason': 'account_rejected', 'status': 'rejected'},
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
          errorMessage = l.accountIsStatus(empStatus);
          isLoading = false;
          notifyListeners();
          return;
      }

      // 4. Initialize E2EE keys.
      //    Generates a fresh X25519 key pair when none exists locally.
      //    Then checks if a backup exists and prompts restore.
      await E2eeManager.initializeKeys(uid);

      // Show restore prompt if:
      //   a) initializeKeys detected a backup (no local keys yet), OR
      //   b) local keys exist but the user never completed restore
      //      (they skipped previously — we re-prompt each login).
      final restoreDone =
          PreferencesManager().getBool('e2ee_restore_done_$uid') ?? false;
      bool shouldPromptRestore = E2eeManager.backupAvailable;

      if (!shouldPromptRestore && !restoreDone) {
        // Local keys exist (from a prior skip) — re-check cloud backup.
        try {
          shouldPromptRestore = await E2eeBackupService.hasBackup(uid);
        } catch (_) {
          shouldPromptRestore = false;
        }
      }

      if (shouldPromptRestore && context.mounted) {
        await _tryRestoreE2eeKeys(context, uid);
      }

      // 4b. Upload FCM device token — fire-and-forget
      PushNotificationService.instance.uploadToken(uid).ignore();

      // 5. Persist session
      final prefs = PreferencesManager();
      await prefs.setString('uid', uid);
      await prefs.setString('email', empData['email'] ?? '');
      await prefs.setString('role', 'employee');
      await prefs.setBool('firstLogin', false);
      await prefs.setBool('mustChangePassword', false);
      if (empOrgId.isNotEmpty) {
        await prefs.setString('organizationId', empOrgId);
      }
      final empOrgName = empData['organizationName'] as String? ?? '';
      if (empOrgName.isNotEmpty) {
        await prefs.setString('organizationName', empOrgName);
      }
      // Persist actor fields used by SessionManager for audit logging.
      final empName = empData['name'] as String? ?? '';
      if (empName.isNotEmpty) await prefs.setString('name', empName);
      final empDisplayId = empData['displayId'] as String? ?? '';
      if (empDisplayId.isNotEmpty) await prefs.setString('displayId', empDisplayId);

      // 6. OTP 2FA — legacy employees (no phoneNumber or phoneVerified != true) bypass.
      final phoneNumber = empData['phoneNumber'] as String? ?? '';
      final phoneVerified = empData['phoneVerified'] as bool? ?? false;

      if (phoneNumber.isNotEmpty && phoneVerified) {
        isLoading = false;
        notifyListeners();

        try {
          await OtpService.instance.sendOtp(phone: phoneNumber, purpose: 'login');
        } catch (e) {
          await FirebaseService.instance.auth.signOut();
          errorMessage = l.otpSendFailed;
          notifyListeners();
          return;
        }

        if (!context.mounted) return;

        final otpVerified = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  phone: phoneNumber,
                  purpose: 'login',
                  uid: uid,
                ),
              ),
            ) ??
            false;

        if (!context.mounted) return;

        if (!otpVerified) {
          await FirebaseService.instance.auth.signOut();
          errorMessage = l.otpVerificationFailed;
          isLoading = false;
          notifyListeners();
          return;
        }

        isLoading = true;
        notifyListeners();
      }

      // 7. Load full employee profile (resolves departmentId, carries phone fields)
      final employee = await _loadEmployeeProfile(uid, empData);
      if (!context.mounted) return;

      // 8. Audit logs
      if (empOrgId.isNotEmpty) {
        LoggingService.instance
            .log(
              organizationId: empOrgId,
              actionType: 'login_success',
              performedByUserId: uid,
              performedByRole: 'employee',
              performedByEmail: employee.email,
              performedByName: employee.name,
              performedByEmployeeId: employee.displayId,
              performedByDepartmentId: employee.departmentId,
            )
            .ignore();
      }

      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeMainScreen(employee: employee),
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

  /// Prompt the user to restore their E2EE keys from a Firestore backup.
  ///
  /// Called after [E2eeManager.initializeKeys] when a backup is detected.
  /// At this point, NO keys have been generated yet — Firestore still has
  /// the user's old public key, so group key docs are still unwrappable.
  ///
  /// The restore dialog decrypts the backup and returns a [BackupManifest]
  /// containing both the identity key AND all conversation AES keys.
  ///
  /// If the user restores: keys are saved and conversation keys are written
  /// to secure storage with their original identifiers.
  /// If the user skips: fresh keys are generated so they can chat this
  /// session, but we do NOT mark restore as complete — the prompt will
  /// reappear on the next login.
  Future<void> _tryRestoreE2eeKeys(BuildContext context, String uid) async {
    if (!context.mounted) return;

    final manifest = await showE2eeRestoreDialog(context, uid);

    if (manifest == null) {
      // User chose to skip for this session.
      debugPrint('[Login] User skipped restore — generating fresh keys');
      // Generate fresh keys so the user can send new messages.
      // Do NOT set e2ee_restore_done — prompt will reappear next login.
      final hasKeys = await E2eeKeyStore.hasKeyPair();
      if (!hasKeys) {
        await E2eeManager.generateFreshKeys(uid);
      }
      return;
    }

    try {
      final result = await E2eeManager.restoreFromManifest(uid, manifest);
      debugPrint('[Login] E2EE restore complete: $result');

      // ── Post-restore validation ──────────────────────────────────────
      // 1. Verify identity key persisted to secure storage.
      final diag = await E2eeManager.diagnostics();
      final hasKeys = diag['hasLocalKeyPair'] == true;
      if (!hasKeys) {
        debugPrint('[Login] CRITICAL: Identity key not persisted after restore');
        await E2eeManager.generateFreshKeys(uid);
        return;
      }

      // 2. Mark restore as done — stop prompting on future logins.
      await PreferencesManager().setBool('e2ee_restore_done_$uid', true);

      // 3. Verify public key fingerprint matches.
      if (!result.fingerprintMatch) {
        debugPrint('[Login] WARNING: Public key fingerprint mismatch after '
            'restore — backup may be from a different key generation');
      }

      // 4. Verify Firestore public key matches restored key.
      final firestorePubKey = await _verifyRestoredKeyInFirestore(uid);
      if (firestorePubKey != null &&
          firestorePubKey != result.restoredPublicKey) {
        debugPrint('[Login] WARNING: Firestore key mismatch — re-publishing');
      }

      // 5. Verify conversation keys are actually readable.
      if (result.hasConversationKeys && !result.allKeysVerified) {
        debugPrint('[Login] WARNING: Some conversation keys failed '
            'verification — '
            '${result.conversationKeysVerified}/${result.conversationKeysRestored} '
            'readable. Old messages may show as encrypted.');
      }

      // 6. Log restore diagnostics.
      debugPrint('[Login] Restore diagnostics: '
          'v${result.manifestVersion} '
          'convKeys=${result.conversationKeysRestored}/'
          '${result.conversationKeysInManifest} '
          'verified=${result.conversationKeysVerified} '
          'fingerprint=${result.fingerprintMatch ? "match" : "MISMATCH"}');
    } catch (e) {
      debugPrint('[Login] E2EE restore FAILED: $e');
      // Restore failed — fall back to generating fresh keys so the user
      // can at least send new messages.
      debugPrint('[Login] Falling back to fresh key generation');
      await E2eeManager.generateFreshKeys(uid);
    }
  }

  /// Read back the public key from Firestore to confirm the restore write
  /// actually persisted.  Returns null on error.
  Future<String?> _verifyRestoredKeyInFirestore(String uid) async {
    try {
      final snap = await FirebaseService.instance.firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      return snap.data()?['e2eePublicKey'] as String?;
    } catch (e) {
      debugPrint('[Login] Firestore key verification failed: $e');
      return null;
    }
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
          FirebaseService.instance.firestore
              .collection('employees')
              .doc(uid)
              .update({'departmentId': deptId})
              .ignore();
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
          phoneNumber: employee.phoneNumber,
          phoneVerified: employee.phoneVerified,
          avatarUrl: employee.avatarUrl,
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
      phoneNumber: (userData['phoneNumber'] as String? ?? ''),
      phoneVerified: (userData['phoneVerified'] as bool? ?? false),
      avatarUrl: (userData['avatarUrl'] as String? ?? ''),
    );
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

  void forgotPassword(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
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
