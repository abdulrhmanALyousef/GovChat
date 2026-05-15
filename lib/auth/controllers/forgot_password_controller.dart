import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/services/logging_service.dart';
import '../../core/services/otp_service.dart';
import '../otp_verification_screen.dart';
import '../reset_password_screen.dart';

class ForgotPasswordController extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;

  Future<void> identify(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context)!;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final email = emailController.text.trim().toLowerCase();

      // 1. Look up employee by email — employees collection only
      final query = await FirebaseService.instance.firestore
          .collection('employees')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'employee')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        errorMessage = l.fpEmployeeNotFound;
        isLoading = false;
        notifyListeners();
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final uid = doc.id;

      // 2. Validate active status
      final status = data['status'] as String? ?? '';
      if (status != 'active') {
        errorMessage = l.fpEmployeeNotFound;
        isLoading = false;
        notifyListeners();
        return;
      }

      // 3. Validate verified phone — legacy employees without phone cannot reset
      final phoneNumber = data['phoneNumber'] as String? ?? '';
      final phoneVerified = data['phoneVerified'] as bool? ?? false;

      if (phoneNumber.isEmpty || !phoneVerified) {
        errorMessage = l.cpNoPhoneMessage;
        isLoading = false;
        notifyListeners();
        return;
      }

      // 4. Send OTP to verified phone
      try {
        await OtpService.instance.sendOtp(
          phone: phoneNumber,
          purpose: 'password_reset',
        );
      } catch (e) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
        notifyListeners();
        return;
      }

      // 5. Audit log — fire-and-forget
      final orgId = data['organizationId'] as String? ?? '';
      if (orgId.isNotEmpty) {
        LoggingService.instance
            .log(
              organizationId: orgId,
              actionType: 'password_reset_otp_sent',
              descriptionKey: 'logPasswordResetViaSms',
              performedByUserId: uid,
              performedByRole: 'employee',
              performedByEmail: email,
              performedByName: data['name'] as String? ?? '',
            )
            .ignore();
      }

      isLoading = false;
      notifyListeners();

      if (!context.mounted) return;

      // 6. OTP verification
      final otpVerified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phone: phoneNumber,
                purpose: 'password_reset',
                uid: uid,
              ),
            ),
          ) ??
          false;

      if (!context.mounted) return;
      if (!otpVerified) return;

      // 7. Proceed to reset password screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            uid: uid,
            organizationId: orgId,
            email: email,
          ),
        ),
      );
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
