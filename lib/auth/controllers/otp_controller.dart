import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/otp_service.dart';

class OtpController extends ChangeNotifier {
  OtpController({
    required this.phone,
    required this.purpose,
    this.uid,
  }) {
    _startCooldown();
  }

  final String phone;
  final String purpose;
  final String? uid;

  final TextEditingController codeController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String? errorMessage;
  int cooldownSeconds = _kCooldown;
  int _attemptCount = 0;

  static const int _kCooldown = 60;
  static const int _kMaxAttempts = 5;

  Timer? _timer;

  void _startCooldown() {
    cooldownSeconds = _kCooldown;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (cooldownSeconds > 0) {
        cooldownSeconds--;
        notifyListeners();
      } else {
        t.cancel();
      }
    });
  }

  Future<void> resend() async {
    if (cooldownSeconds > 0) return;

    errorMessage = null;
    notifyListeners();

    try {
      await OtpService.instance.sendOtp(phone: phone, purpose: purpose);
      _startCooldown();
      codeController.clear();
    } on Exception catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  /// Returns true when the server confirms the OTP is valid.
  Future<bool> verify() async {
    if (!formKey.currentState!.validate()) return false;

    if (_attemptCount >= _kMaxAttempts) {
      errorMessage = 'Too many failed attempts. Please request a new code.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final verified = await OtpService.instance.verifyOtp(
        phone: phone,
        otp: codeController.text.trim(),
        purpose: purpose,
        uid: uid,
      );

      if (verified) {
        isLoading = false;
        notifyListeners();
        return true;
      }

      _attemptCount++;
      final left = _kMaxAttempts - _attemptCount;
      errorMessage = left > 0
          ? 'Invalid OTP. $left attempt${left == 1 ? '' : 's'} remaining.'
          : 'Invalid OTP. No attempts left — please request a new code.';
    } on Exception catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  bool get attemptsExhausted => _attemptCount >= _kMaxAttempts;

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }
}
