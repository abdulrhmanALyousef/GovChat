import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/App_color.dart';
import '../core/constants/app_size.dart';
import '../core/Widgets/text_field_for_login.dart';
import 'controllers/change_password_controller.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChangePasswordController(),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatelessWidget {
  const _ChangePasswordView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChangePasswordController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Section ──
                Center(
                  child: Column(
                    children: [
                      SizedBox(height: AppSizes.ph60),

                      // ── Logo ──
                      Container(
                        width: AppSizes.w90,
                        height: AppSizes.h90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.r24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowDark,
                              blurRadius: AppSizes.r20,
                              offset: Offset(0, AppSizes.h8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppSizes.r24),
                          child: Image.asset(
                            'assets/govchat_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.h24),

                      Text(
                        'Change Password',
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTitle,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),

                      Text(
                        'To maintain sovereign security, you must update\nyour temporary password before proceeding.',
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

                // ── New Password ──
                Text(
                  'NEW PASSWORD',
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
                    if (v == null || v.isEmpty) return 'Required';
                    if (!controller.hasMinLength) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.ph20),

                // ── Confirm Password ──
                Text(
                  'CONFIRM PASSWORD',
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
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != controller.newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.ph24),

                // ── Password Rules ──
                _buildRule('Minimum 8 characters', controller.hasMinLength),
                SizedBox(height: AppSizes.ph12),
                _buildRule('At least 1 uppercase letter', controller.hasUppercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule('At least 1 lowercase letter', controller.hasLowercase),
                SizedBox(height: AppSizes.ph12),
                _buildRule('At least 1 number', controller.hasNumber),
                SizedBox(height: AppSizes.ph12),
                _buildRule('At least 1 special character', controller.hasSpecialChar),
                SizedBox(height: AppSizes.ph30),

                // ── Error Message ──
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

                // ── Update Button ──
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
                      onPressed: controller.isLoading ? null : () => controller.updatePassword(context),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Update Password',
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