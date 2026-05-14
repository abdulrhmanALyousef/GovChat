import 'package:cloud_functions/cloud_functions.dart';

class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Sends an OTP via Authentica.sa SMS to [phone] (international format).
  /// [purpose]: "access_request" | "login" | "password_reset"
  /// Throws [Exception] on failure (includes server rate-limit messages).
  Future<void> sendOtp({
    required String phone,
    required String purpose,
  }) async {
    final callable = _functions.httpsCallable('sendOtp');
    final result = await callable.call({'phone': phone, 'purpose': purpose});
    final data = result.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
  }

  /// Verifies the [otp] code for [phone] (international format).
  /// Returns true when the server confirms the code is valid.
  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required String purpose,
    String? uid,
  }) async {
    final callable = _functions.httpsCallable('verifyOtp');
    final result = await callable.call({
      'phone': phone,
      'otp': otp,
      'purpose': purpose,
      'uid': uid,
    });
    final data = result.data as Map<String, dynamic>;
    return data['success'] == true;
  }

  /// Converts a Saudi local mobile number to international format for Authentica.sa.
  ///
  /// Accepts:  05XXXXXXXX  (10 digits, Saudi mobile starting with 05)
  /// Returns:  +966XXXXXXXXX  (drops the leading 0, prepends +966)
  ///
  /// Throws [FormatException] for non-Saudi or invalid numbers.
  static String formatSaudiPhone(String localPhone) {
    final p = localPhone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (!RegExp(r'^05[0-9]{8}$').hasMatch(p)) {
      throw FormatException(
        'Invalid Saudi mobile number. Use format: 05XXXXXXXX',
      );
    }
    // Drop the leading 0, prepend +966
    return '+966${p.substring(1)}';
  }

  /// Validates a Saudi local mobile number without converting it.
  static bool isValidSaudiPhone(String localPhone) {
    final p = localPhone.trim().replaceAll(' ', '').replaceAll('-', '');
    return RegExp(r'^05[0-9]{8}$').hasMatch(p);
  }

  /// Returns a display-safe masked version of the international phone.
  /// "+966597123456" → "+966****456"
  static String maskPhone(String phone) {
    final p = phone.trim();
    if (p.length < 7) return p;
    final prefix = p.length >= 10 ? p.substring(0, 5) : p.substring(0, 3);
    final suffix = p.substring(p.length - 3);
    return '$prefix****$suffix';
  }
}
