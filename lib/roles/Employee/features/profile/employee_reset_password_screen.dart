import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../auth/otp_verification_screen.dart';
import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/Widgets/text_field_for_login.dart';
import 'controller/employee_reset_password_controller.dart';

class EmployeeResetPasswordScreen extends StatelessWidget {
  const EmployeeResetPasswordScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.phoneVerified,
  });

  final String uid;
  final String email;
  final String phoneNumber;
  final bool phoneVerified;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmployeeResetPasswordController(
        uid: uid,
        email: email,
        phoneNumber: phoneNumber,
        phoneVerified: phoneVerified,
      ),
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView();

  Future<void> _submit(BuildContext context) async {
    final controller = context.read<EmployeeResetPasswordController>();
    final l = AppLocalizations.of(context)!;

    final otpReady = await controller.prepareOtp(context);
    if (!otpReady || !context.mounted) return;

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phone: controller.phoneNumber,
          purpose: 'password_reset',
          uid: controller.uid,
        ),
      ),
    );

    if (verified != true || !context.mounted) return;

    final success = await controller.finalizeUpdate(context);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.passwordChangedSuccessfully,
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: AppColors.primaryColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EmployeeResetPasswordController>();
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
          l.resetPasswordTitle,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSizes.ph40),

                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSizes.ph20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset_outlined,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp40,
                        ),
                      ),
                      SizedBox(height: AppSizes.h24),
                      Text(
                        l.resetPasswordTitle,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),
                      Text(
                        l.changePasswordDescription,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp12,
                          color: AppColors.textSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSizes.ph40),

                // Current Password
                Text(
                  l.currentPasswordLabel,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                TextFieldForLogin(
                  controller: controller.currentPasswordController,
                  hintText: '············',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.ph20),

                // New Password
                Text(
                  l.newPasswordLabel,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                TextFieldForLogin(
                  controller: controller.newPasswordController,
                  hintText: '············',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    if (!controller.hasMinLength) return l.minimumEightChars;
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.ph20),

                // Confirm Password
                Text(
                  l.confirmPasswordLabel,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                TextFieldForLogin(
                  controller: controller.confirmPasswordController,
                  hintText: '············',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    if (v != controller.newPasswordController.text) {
                      return l.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.ph24),

                // Password Rules
                _buildRule(l.ruleMinChars, controller.hasMinLength),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleUppercase, controller.hasUppercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleLowercase, controller.hasLowercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleNumber, controller.hasNumber),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleSpecialChar, controller.hasSpecialChar),
                SizedBox(height: AppSizes.ph30),

                // Error Message
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

                // Submit Button
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
                      onPressed: controller.isLoading
                          ? null
                          : () => _submit(context),
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
                                  l.updatePasswordButton,
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

                SizedBox(height: AppSizes.ph30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRule(String text, bool isValid) {
    return Container(
      width: double.infinity,
      height: AppSizes.h44,
      padding: EdgeInsets.all(AppSizes.ph12),
      decoration: BoxDecoration(
        color: AppColors.ruleBackground,
        borderRadius: BorderRadius.circular(AppSizes.r8),
        border: Border.all(
          color: isValid
              ? AppColors.primaryColor.withValues(alpha: 0.4)
              : AppColors.inputBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: AppSizes.sp18,
            color: isValid ? AppColors.primaryColor : AppColors.textSecondary,
          ),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: AppSizes.sp12,
                color: isValid ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
