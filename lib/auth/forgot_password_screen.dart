import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/Widgets/text_field_for_login.dart';
import '../core/constants/app_size.dart';
import '../core/theme/app_color.dart';
import 'controllers/forgot_password_controller.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordController(),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ForgotPasswordController>();
    final l = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          l.fpTitle,
          style: GoogleFonts.manrope(
            color: colors.textPrimary,
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
                SizedBox(height: AppSizes.ph40),

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
                  l.fpTitle,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp20,
                    fontWeight: FontWeight.w800,
                    color: colors.textTitle,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSizes.h8),

                Text(
                  l.fpSubtitle,
                  style: GoogleFonts.manrope(
                    fontSize: AppSizes.sp13,
                    color: colors.textSubtitle,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSizes.ph40),

                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.emailLabel,
                    style: GoogleFonts.manrope(
                      fontSize: AppSizes.sp12,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                TextFieldForLogin(
                  controller: ctrl.emailController,
                  hintText: l.enterEmailHint,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l.requiredField : null,
                ),
                SizedBox(height: AppSizes.ph30),

                if (ctrl.errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: AppSizes.ph16),
                    padding: EdgeInsets.all(AppSizes.ph14),
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
                          : () => ctrl.identify(context),
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
                              height: AppSizes.h22,
                              width: AppSizes.w22,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Text(
                              l.fpIdentifyButton,
                              style: GoogleFonts.manrope(
                                fontSize: AppSizes.sp16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),

                SizedBox(height: AppSizes.ph20),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l.backToLogin,
                    style: GoogleFonts.manrope(
                      color: colors.textMuted,
                      fontSize: AppSizes.sp14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
