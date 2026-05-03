import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class VerificationCodeController extends ChangeNotifier {
  VerificationCodeController({required this.uid, required this.email}) {
    _sendCode();
  }

  final String uid;
  final String email;

  final TextEditingController codeController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool isSendingCode = true;
  bool codeSent = false;
  String? errorMessage;
  String? successMessage;

  Future<void> _sendCode() async {
    isSendingCode = true;
    errorMessage = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('sendPasswordResetCode');
      final result = await callable.call({'uid': uid, 'email': email});

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        codeSent = true;
      } else {
        errorMessage = data['message'] as String? ?? 'Failed to send code.';
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isSendingCode = false;
    notifyListeners();
  }

  Future<void> resendCode() async {
    successMessage = null;
    await _sendCode();
    if (codeSent && errorMessage == null) {
      successMessage = 'resent';
      notifyListeners();
    }
  }

  Future<bool> verifyCode(BuildContext context) async {
    if (!formKey.currentState!.validate()) return false;

    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('verifyPasswordResetCode');
      final result = await callable.call({
        'uid': uid,
        'code': codeController.text.trim(),
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        isLoading = false;
        notifyListeners();
        return true;
      } else {
        errorMessage = data['message'] as String?;
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }
}
