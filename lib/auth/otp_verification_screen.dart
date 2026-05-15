import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_size.dart';
import '../core/services/otp_service.dart';
import '../core/theme/app_color.dart';
import 'controllers/otp_controller.dart';

/// Reusable OTP screen. Pops with [true] on verified, [false] / null on cancel.
///
/// [purpose]: "access_request" | "login" | "password_reset"
class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.purpose,
    this.uid,
  });

  final String phone;
  final String purpose;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OtpController(phone: phone, purpose: purpose, uid: uid),
      child: _OtpView(maskedPhone: OtpService.maskPhone(phone), purpose: purpose),
    );
  }
}

class _OtpView extends StatelessWidget {
  const _OtpView({required this.maskedPhone, required this.purpose});

  final String maskedPhone;
  final String purpose;

  bool get _isLogin => purpose == 'login';

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OtpController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        centerTitle: true,
        title: Text(
          _isLogin ? l.otpLoginTitle : l.otpVerificationTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: ctrl.formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
            child: Column(
              children: [
                SizedBox(height: AppSizes.ph60),

                // Icon
                Container(
                  padding: EdgeInsets.all(AppSizes.ph20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLogin ? Icons.security_outlined : Icons.phone_android_outlined,
                    color: AppColors.primaryColor,
                    size: AppSizes.sp40,
                  ),
                ),
                SizedBox(height: AppSizes.h24),

                Text(
                  _isLogin ? l.otpLoginTitle : l.otpVerificationTitle,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSizes.h8),

                Text(
                  _isLogin ? l.otpLoginSubtitle : l.otpVerificationSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    color: AppColors.textSubtitle,
                    height: 1.5,
                  ),
                ),
                if (!_isLogin) ...[
                  SizedBox(height: AppSizes.h8),
                  Text(
                    maskedPhone,
                    style: GoogleFonts.manrope(
                      fontSize: AppSizes.sp14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],

                SizedBox(height: AppSizes.ph40),

                // OTP input label
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.otpEnterCode.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: AppSizes.sp11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: AppSizes.h8),

                // OTP input — 4 digits, auto-submits when complete
                TextFormField(
                  controller: ctrl.codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  enabled: !ctrl.attemptsExhausted,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) async {
                    if (v.length == 4 && !ctrl.isLoading) {
                      final verified = await ctrl.verify();
                      if (verified && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.sp32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 18,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.pw16,
                      vertical: AppSizes.ph16,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    if (v.length != 4) return l.otpEnterCode;
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.ph24),

                // Error banner
                if (ctrl.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: AppSizes.ph16),
                    padding: EdgeInsets.all(AppSizes.ph12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      ctrl.errorMessage!,
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontSize: AppSizes.sp12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.h56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ctrl.attemptsExhausted
                          ? null
                          : const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                            ),
                      color: ctrl.attemptsExhausted ? AppColors.inputFill : null,
                      borderRadius: BorderRadius.circular(AppSizes.r16),
                    ),
                    child: ElevatedButton(
                      onPressed: (ctrl.isLoading || ctrl.attemptsExhausted)
                          ? null
                          : () async {
                              final verified = await ctrl.verify();
                              if (verified && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r16),
                        ),
                      ),
                      child: ctrl.isLoading
                          ? SizedBox(
                              height: AppSizes.h24,
                              width: AppSizes.w24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Text(
                              l.otpVerifyButton,
                              style: GoogleFonts.manrope(
                                fontSize: AppSizes.sp14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),

                SizedBox(height: AppSizes.ph16),

                // Resend button / countdown
                ctrl.cooldownSeconds > 0
                    ? Text(
                        l.otpResendIn(ctrl.cooldownSeconds),
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted,
                          fontSize: AppSizes.sp13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : TextButton(
                        onPressed: ctrl.isLoading ? null : () => ctrl.resend(),
                        child: Text(
                          l.otpResendButton,
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp13,
                          ),
                        ),
                      ),

                SizedBox(height: AppSizes.ph30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
