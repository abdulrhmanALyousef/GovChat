import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          l.profileTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.pw24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSizes.ph12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.r12),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primaryColor,
                        size: 26,
                      ),
                    ),
                    SizedBox(width: AppSizes.w12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.primaryAdminSession,
                            style: GoogleFonts.manrope(
                              color: AppColors.textTitle,
                              fontSize: AppSizes.sp18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: AppSizes.h6),
                          Text(
                            l.primaryAdminSessionDescription,
                            style: GoogleFonts.manrope(
                              color: AppColors.textSubtitle,
                              fontSize: AppSizes.sp12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.ph16),

              // ── Language Switcher Card ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp20,
                        ),
                        SizedBox(width: AppSizes.w12),
                        Text(
                          l.languageLabel,
                          style: GoogleFonts.manrope(
                            color: AppColors.textTitle,
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => localeProvider.toggleLocale(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.pw12,
                          vertical: AppSizes.ph6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sectionBackground,
                          borderRadius: BorderRadius.circular(AppSizes.r20),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: Text(
                          localeProvider.isArabic
                              ? l.englishLanguage
                              : l.arabicLanguage,
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryColor,
                            fontSize: AppSizes.sp12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSizes.ph16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.sessionControlsSection,
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSizes.h10),
                    Text(
                      l.signOutSecurelyDescription,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSubtitle,
                        fontSize: AppSizes.sp12,
                      ),
                    ),
                    SizedBox(height: AppSizes.ph16),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.h48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.gradientStart,
                              AppColors.gradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmLogout(context, l),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.r12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.buttonText,
                          ),
                          label: Text(
                            l.logoutButton,
                            style: GoogleFonts.manrope(
                              color: AppColors.buttonText,
                              fontWeight: FontWeight.w800,
                              fontSize: AppSizes.sp14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l) async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                l.confirmLogoutTitle,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                l.confirmLogoutContent,
                style: GoogleFonts.manrope(
                  color: AppColors.textSubtitle,
                  fontSize: AppSizes.sp13,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    l.cancelUppercase,
                    style: GoogleFonts.manrope(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    l.logoutUppercase,
                    style: GoogleFonts.manrope(color: AppColors.primaryColor),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !context.mounted) return;

    await SessionManager.instance.logout(context);
  }
}