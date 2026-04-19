import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../core/theme/app_color.dart';
import '../core/constants/app_size.dart';
import '../core/Widgets/text_field_for_login.dart';
import '../core/providers/locale_provider.dart';
import 'controllers/login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LoginController>();
    final l = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Language Switcher ──
                Padding(
                  padding: EdgeInsets.only(
                    top: AppSizes.h16,
                    right: AppSizes.pw16,
                    left: AppSizes.pw16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _LanguageSwitcher(localeProvider: localeProvider, l: l),
                    ],
                  ),
                ),

                // ── Top Section ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: AppSizes.ph60),
                  child: Column(
                    children: [
                      // ── Logo Container ──
                      Container(
                        width: AppSizes.w90,
                        height: AppSizes.h90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.r24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowDark,
                              blurRadius: AppSizes.r20,
                              offset: Offset(0, AppSizes.h10),
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

                      // ── App Name ──
                      Text(
                        l.appName,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textTitle,
                          letterSpacing: 3,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),

                      Text(
                        l.loginTitle,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTitle,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),

                      Text(
                        l.secureAccessSubtitle,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp14,
                          color: AppColors.textSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSizes.h16),

                // ── Form Section ──
                Container(
                  margin: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
                  padding: EdgeInsets.all(AppSizes.ph20),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(AppSizes.r16),
                    border: Border.all(color: AppColors.formBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: AppSizes.h32,
                        offset: Offset(0, AppSizes.h16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Email ──
                      Text(
                        l.emailLabel,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.emailController,
                        hintText: l.enterEmailHint,
                        icon: Icons.email_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? l.requiredField : null,
                      ),
                      SizedBox(height: AppSizes.ph20),

                      // ── Password ──
                      Text(
                        l.passwordLabel,
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.passwordController,
                        hintText: l.enterPasswordHint,
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? l.requiredField : null,
                      ),
                      SizedBox(height: AppSizes.h32),

                      // ── Error Message ──
                      if (controller.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: AppSizes.ph20),
                          padding: EdgeInsets.all(AppSizes.ph14),
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

                      // ── Login Button ──
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
                                : () => controller.login(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: AppColors.buttonText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.r16,
                                ),
                              ),
                            ),
                            child: controller.isLoading
                                ? SizedBox(
                                    height: AppSizes.h22,
                                    width: AppSizes.w22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.buttonText,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l.loginTitle,
                                        style: GoogleFonts.manrope(
                                          fontSize: AppSizes.sp16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(width: AppSizes.w10),
                                      Image.asset(
                                        'assets/icons/loginIcon.png',
                                        width: AppSizes.w22,
                                        height: AppSizes.h22,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.h14),

                      // ── Request Access Button ──
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.h56,
                        child: OutlinedButton(
                          onPressed: () => controller.requestAccess(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.inputBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.r16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l.requestAccessButton,
                                style: GoogleFonts.manrope(
                                  fontSize: AppSizes.sp16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              SizedBox(width: AppSizes.w10),
                              Icon(
                                Icons.person_add_outlined,
                                color: AppColors.textMuted,
                                size: AppSizes.sp20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.ph20),

                      // ── Forgot Password ──
                      Center(
                        child: TextButton(
                          onPressed: controller.forgotPassword,
                          child: Text(
                            l.forgotPasswordButton,
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                              fontSize: AppSizes.sp14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Footer ──
                Padding(
                  padding: EdgeInsets.only(
                    bottom: AppSizes.h32,
                    top: AppSizes.h16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: AppSizes.w30,
                        height: 1,
                        color: AppColors.inputBorder,
                      ),
                      SizedBox(width: AppSizes.w8),
                      Icon(
                        Icons.verified_user_outlined,
                        size: AppSizes.sp14,
                        color: AppColors.hintText,
                      ),
                      SizedBox(width: AppSizes.w6),
                      Flexible(
                        child: Text(
                          l.endToEndEncrypted,
                          style: GoogleFonts.manrope(
                            fontSize: AppSizes.sp10,
                            color: AppColors.hintText,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: AppSizes.w8),
                      Container(
                        width: AppSizes.w30,
                        height: 1,
                        color: AppColors.inputBorder,
                      ),
                    ],
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

// ── Language Switcher Widget ──
class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({
    required this.localeProvider,
    required this.l,
  });

  final LocaleProvider localeProvider;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isArabic = localeProvider.isArabic;
    return GestureDetector(
      onTap: () => localeProvider.toggleLocale(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph6,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              color: AppColors.primaryColor,
              size: AppSizes.sp16,
            ),
            SizedBox(width: AppSizes.w6),
            Text(
              isArabic ? l.englishLanguage : l.arabicLanguage,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontSize: AppSizes.sp12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
