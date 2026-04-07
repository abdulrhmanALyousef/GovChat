import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
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
                        Icons.verified_user_outlined,
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
                            'Admin Session',
                            style: GoogleFonts.manrope(
                              color: AppColors.textTitle,
                              fontSize: AppSizes.sp18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: AppSizes.h6),
                          Text(
                            'Securely manage your admin account and sign out when finished.',
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
              SizedBox(height: AppSizes.ph24),
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
                      'SESSION CONTROLS',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSizes.h10),
                    Text(
                      'End your session and clear cached data from this device.',
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
                          onPressed: () => _confirmLogout(context),
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
                            'Logout',
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

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                'Confirm Logout',
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                'This will sign you out and clear your local session.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSubtitle,
                  fontSize: AppSizes.sp13,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'LOGOUT',
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
