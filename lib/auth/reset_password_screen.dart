import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/Widgets/text_field_for_login.dart';
import '../core/constants/app_size.dart';
import '../core/theme/app_color.dart';
import 'controllers/reset_password_controller.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({
    super.key,
    required this.uid,
    required this.organizationId,
    required this.email,
  });

  final String uid;
  final String organizationId;
  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResetPasswordController(
        uid: uid,
        organizationId: organizationId,
        email: email,
      ),
      child: const _ResetPasswordView(),
    );
  }
}

class _ResetPasswordView extends StatelessWidget {
  const _ResetPasswordView();

  Future<void> _submit(BuildContext context) async {
    final ctrl = context.read<ResetPasswordController>();
    final l = AppLocalizations.of(context)!;

    final success = await ctrl.resetPassword(context);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.fpPasswordResetSuccess,
            style: GoogleFonts.manrope(),
          ),
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
      // Return to login screen — pop entire forgot-password stack
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ResetPasswordController>();
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
          key: ctrl.formKey,
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
                        l.resetPasswordSubtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp12,
                          color: AppColors.textSubtitle,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSizes.ph40),

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
                  controller: ctrl.newPasswordController,
                  hintText: '············',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    if (!ctrl.hasMinLength) return l.minimumEightChars;
                    if (!ctrl.hasUppercase || !ctrl.hasLowercase ||
                        !ctrl.hasNumber || !ctrl.hasSpecialChar) {
                      return l.mustContainSpecialChar;
                    }
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
                  controller: ctrl.confirmPasswordController,
                  hintText: '············',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.requiredField;
                    if (v != ctrl.newPasswordController.text) {
                      return l.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),

                SizedBox(height: AppSizes.ph24),

                // Password strength rules
                _buildRule(l.ruleMinChars, ctrl.hasMinLength),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleUppercase, ctrl.hasUppercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleLowercase, ctrl.hasLowercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleNumber, ctrl.hasNumber),
                SizedBox(height: AppSizes.ph12),
                _buildRule(l.ruleSpecialChar, ctrl.hasSpecialChar),

                SizedBox(height: AppSizes.ph30),

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

                // Submit button
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
                      onPressed: ctrl.isLoading
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
                      child: ctrl.isLoading
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
                                  l.fpResetPasswordButton,
                                  style: GoogleFonts.manrope(
                                    fontSize: AppSizes.sp16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: AppSizes.w8),
                                Icon(
                                  Icons.check_circle_outline,
                                  size: AppSizes.sp20,
                                ),
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
            isValid
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: AppSizes.sp18,
            color: isValid ? AppColors.primaryColor : AppColors.textSecondary,
          ),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: AppSizes.sp12,
                color:
                    isValid ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
