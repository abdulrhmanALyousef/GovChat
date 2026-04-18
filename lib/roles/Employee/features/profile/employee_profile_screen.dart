import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';

class EmployeeProfileScreen extends StatelessWidget {
  const EmployeeProfileScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSizes.pw24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Identity Card ──
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
                        Icons.badge_outlined,
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
                            employee.name,
                            style: GoogleFonts.manrope(
                              color: AppColors.textTitle,
                              fontSize: AppSizes.sp18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: AppSizes.h4),
                          Text(
                            employee.email,
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                              fontSize: AppSizes.sp12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSizes.ph16),

              // ── Info Card ──
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
                      'EMPLOYEE INFO',
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSizes.h12),
                    _InfoRow(
                      icon: Icons.business_outlined,
                      label: 'Organization',
                      value: employee.organizationName,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.workspaces_outlined,
                      label: 'Department',
                      value: employee.department,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.tag_outlined,
                      label: 'Employee ID',
                      value: employee.displayId.isNotEmpty
                          ? employee.displayId
                          : '—',
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSizes.ph16),

              // ── Session Controls ──
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
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.textPrimary,
                        ),
                        label: Text(
                          'Sign Out',
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: AppSizes.sp14,
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
    final shouldLogout = await _showLogoutDialog(context);
    if (!shouldLogout || !context.mounted) return;
    await SessionManager.instance.logout(context);
  }
}

Future<bool> _showLogoutDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.r20),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSizes.pw24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.ph16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: AppSizes.sp28,
                  ),
                ),
                SizedBox(height: AppSizes.h16),
                Text(
                  'Sign Out',
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: AppSizes.sp18,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                Text(
                  'You will be signed out and your local session will be cleared from this device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: AppSizes.h24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppSizes.ph14,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSizes.w12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppSizes.ph14,
                          ),
                        ),
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.ph8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: AppSizes.sp16),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSizes.h2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontSize: AppSizes.sp13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.inputBorder, height: 1, thickness: 1);
  }
}