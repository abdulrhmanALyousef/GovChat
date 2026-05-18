import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:projects/l10n/app_localizations.dart';
import '../core/theme/app_color.dart';
import '../core/constants/app_size.dart';
import '../core/Widgets/text_field_for_login.dart';
import '../core/providers/locale_provider.dart';
import '../core/providers/theme_provider.dart';
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
    final themeProvider = context.watch<ThemeProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // ── Top bar: Language + Theme switchers ──
                        Padding(
                          padding: EdgeInsets.only(
                            top: AppSizes.h12,
                            right: AppSizes.pw16,
                            left: AppSizes.pw16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _ThemeSwitcher(
                                themeProvider: themeProvider,
                                l: l,
                              ),
                              SizedBox(width: AppSizes.w8),
                              _LanguageSwitcher(
                                localeProvider: localeProvider,
                                l: l,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 1),

                        // ── Branding ──
                        Column(
                          children: [
                            Container(
                              width: AppSizes.w90,
                              height: AppSizes.h90,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.r24),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadowDark,
                                    blurRadius: AppSizes.r16,
                                    offset: Offset(0, AppSizes.h8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.r24),
                                child: Image.asset(
                                  'assets/govchat_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: AppSizes.h16),
                            Text(
                              l.appName,
                              style: GoogleFonts.manrope(
                                fontSize: AppSizes.sp28,
                                fontWeight: FontWeight.w900,
                                color: colors.textTitle,
                                letterSpacing: 3,
                              ),
                            ),
                            SizedBox(height: AppSizes.h6),
                            Text(
                              l.secureAccessSubtitle,
                              style: GoogleFonts.manrope(
                                fontSize: AppSizes.sp13,
                                color: colors.textSubtitle,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // ── Form card ──
                        Container(
                          margin: EdgeInsets.symmetric(
                              horizontal: AppSizes.pw24),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.pw20,
                            vertical: AppSizes.ph16,
                          ),
                          decoration: BoxDecoration(
                            color: colors.scaffoldBackground,
                            borderRadius:
                                BorderRadius.circular(AppSizes.r16),
                            border:
                                Border.all(color: colors.formBorder, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadowColor,
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
                                  color: colors.textMuted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: AppSizes.h6),
                              TextFieldForLogin(
                                controller: controller.emailController,
                                hintText: l.enterEmailHint,
                                icon: Icons.email_outlined,
                                validator: (v) => v == null || v.isEmpty
                                    ? l.requiredField
                                    : null,
                              ),
                              SizedBox(height: AppSizes.h16),

                              // ── Password ──
                              Text(
                                l.passwordLabel,
                                style: GoogleFonts.manrope(
                                  fontSize: AppSizes.sp12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textMuted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: AppSizes.h6),
                              TextFieldForLogin(
                                controller: controller.passwordController,
                                hintText: l.enterPasswordHint,
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: (v) => v == null || v.isEmpty
                                    ? l.requiredField
                                    : null,
                              ),
                              SizedBox(height: AppSizes.h20),

                              // ── Error Message ──
                              if (controller.errorMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(
                                      bottom: AppSizes.ph12),
                                  padding: EdgeInsets.all(AppSizes.ph12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppSizes.r12),
                                    border: Border.all(
                                      color: AppColors.error
                                          .withValues(alpha: 0.3),
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
                              ],

                              // ── Login Button ──
                              SizedBox(
                                width: double.infinity,
                                height: AppSizes.h52,
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
                                    borderRadius:
                                        BorderRadius.circular(AppSizes.r16),
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
                                            AppSizes.r16),
                                      ),
                                    ),
                                    child: controller.isLoading
                                        ? SizedBox(
                                            height: AppSizes.h22,
                                            width: AppSizes.w22,
                                            child:
                                                const CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: AppColors.buttonText,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                              SizedBox(height: AppSizes.h10),

                              // ── Request Access Button ──
                              SizedBox(
                                width: double.infinity,
                                height: AppSizes.h52,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      controller.requestAccess(context),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: colors.inputBorder,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.r16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        l.requestAccessButton,
                                        style: GoogleFonts.manrope(
                                          fontSize: AppSizes.sp16,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                      SizedBox(width: AppSizes.w10),
                                      Icon(
                                        Icons.person_add_outlined,
                                        color: colors.textMuted,
                                        size: AppSizes.sp20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Forgot Password ──
                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      controller.forgotPassword(context),
                                  child: Text(
                                    l.forgotPasswordButton,
                                    style: GoogleFonts.manrope(
                                      color: colors.textMuted,
                                      fontSize: AppSizes.sp14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 1),

                        // ── Footer ──
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: AppSizes.h16,
                            top: AppSizes.h8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: AppSizes.w30,
                                height: 1,
                                color: colors.inputBorder,
                              ),
                              SizedBox(width: AppSizes.w8),
                              Icon(
                                Icons.verified_user_outlined,
                                size: AppSizes.sp14,
                                color: colors.hintText,
                              ),
                              SizedBox(width: AppSizes.w6),
                              Flexible(
                                child: Text(
                                  l.endToEndEncrypted,
                                  style: GoogleFonts.manrope(
                                    fontSize: AppSizes.sp10,
                                    color: colors.hintText,
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
                                color: colors.inputBorder,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Theme Switcher Widget ──
class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher({
    required this.themeProvider,
    required this.l,
  });

  final ThemeProvider themeProvider;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    return GestureDetector(
      onTap: () => themeProvider.setTheme(
        isDark ? ThemeMode.light : ThemeMode.dark,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph6,
        ),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(color: colors.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: AppColors.primaryColor,
              size: AppSizes.sp16,
            ),
            SizedBox(width: AppSizes.w6),
            Text(
              isDark ? l.themeLight : l.themeDark,
              style: GoogleFonts.manrope(
                color: colors.textMuted,
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
    final colors = context.colors;
    final isArabic = localeProvider.isArabic;
    return GestureDetector(
      onTap: () => localeProvider.toggleLocale(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph6,
        ),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(color: colors.inputBorder),
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
                color: colors.textMuted,
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
