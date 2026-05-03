import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import 'controller/verification_code_controller.dart';
import 'employee_reset_password_screen.dart';

class VerificationCodeScreen extends StatelessWidget {
  const VerificationCodeScreen({
    super.key,
    required this.uid,
    required this.email,
  });

  final String uid;
  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VerificationCodeController(uid: uid, email: email),
      child: const _VerificationCodeView(),
    );
  }
}

class _VerificationCodeView extends StatelessWidget {
  const _VerificationCodeView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VerificationCodeController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          l.verificationCodeTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: controller.formKey,
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
                    Icons.mark_email_read_outlined,
                    color: AppColors.primaryColor,
                    size: AppSizes.sp40,
                  ),
                ),
                SizedBox(height: AppSizes.h24),

                Text(
                  l.verificationCodeTitle,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                ),
                SizedBox(height: AppSizes.h8),

                Text(
                  l.verificationCodeSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    color: AppColors.textSubtitle,
                  ),
                ),
                SizedBox(height: AppSizes.h8),

                // Show masked email
                Text(
                  controller.email,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),

                SizedBox(height: AppSizes.ph40),

                // Sending indicator
                if (controller.isSendingCode)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSizes.ph16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: AppSizes.sp16,
                          height: AppSizes.sp16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        SizedBox(width: AppSizes.w8),
                        Text(
                          l.sendingCode,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: AppSizes.sp12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Code input
                Text(
                  l.enterCodeHint.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppSizes.h8),

                TextFormField(
                  controller: controller.codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.sp24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 12,
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
                    if (v.length != 6) return l.enterCodeHint;
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.ph24),

                // Success message
                if (controller.successMessage != null)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: AppSizes.ph16),
                    padding: EdgeInsets.all(AppSizes.ph12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                      border: Border.all(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      l.codeResent,
                      style: GoogleFonts.manrope(
                        color: AppColors.primaryColor,
                        fontSize: AppSizes.sp12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Error message
                if (controller.errorMessage != null)
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
                      controller.errorMessage!,
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
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.r16),
                    ),
                    child: ElevatedButton(
                      onPressed:
                          controller.isLoading || controller.isSendingCode
                          ? null
                          : () async {
                              final verified = await controller.verifyCode(
                                context,
                              );
                              if (verified && context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeResetPasswordScreen(
                                      uid: controller.uid,
                                    ),
                                  ),
                                );
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
                      child: controller.isLoading
                          ? SizedBox(
                              height: AppSizes.h24,
                              width: AppSizes.w24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l.verifyButton,
                                  style: GoogleFonts.manrope(
                                    fontSize: AppSizes.sp16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: AppSizes.w8),
                                Icon(Icons.arrow_forward, size: AppSizes.sp20),
                              ],
                            ),
                    ),
                  ),
                ),

                SizedBox(height: AppSizes.ph16),

                // Resend code button
                TextButton(
                  onPressed: controller.isSendingCode || controller.isLoading
                      ? null
                      : () => controller.resendCode(),
                  child: Text(
                    l.resendCodeButton,
                    style: GoogleFonts.manrope(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
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
