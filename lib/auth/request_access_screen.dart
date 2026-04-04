import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/App_color.dart';
import '../core/constants/app_size.dart';
import '../core/Widgets/text_field_for_login.dart';
import 'controllers/request_access_controller.dart';

class RequestAccessScreen extends StatelessWidget {
  const RequestAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RequestAccessController(),
      child: const _RequestAccessView(),
    );
  }
}

class _RequestAccessView extends StatelessWidget {
  const _RequestAccessView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RequestAccessController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Bar ──
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw24,
                    vertical: AppSizes.h16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              color: AppColors.primaryColor,
                              size: AppSizes.sp18),
                          SizedBox(width: AppSizes.w6),
                          Text(
                            'GOVCHAT',
                            style: GoogleFonts.manrope(
                              fontSize: AppSizes.sp14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textTitle,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => controller.backToLogin(context),
                        child: Text(
                          'BACK TO LOGIN',
                          style: GoogleFonts.manrope(
                            fontSize: AppSizes.sp11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Badge ──
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.w10,
                          vertical: AppSizes.h4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.r6),
                        ),
                        child: Text(
                          'SECURE ACCESS',
                          style: GoogleFonts.manrope(
                            fontSize: AppSizes.sp10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.h12),

                      // ── Title ──
                      Text(
                        'Request Access',
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textTitle,
                        ),
                      ),
                      SizedBox(height: AppSizes.h8),

                      Text(
                        'Join the sovereign communications network. Your identity will be verified against national records.',
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: AppSizes.h24),

                      // ── Info Cards ──
                      _buildInfoCard(
                        icon: Icons.shield_outlined,
                        title: 'End-to-End Encryption',
                        subtitle: 'All communications are secured with military-grade protocols.',
                      ),
                      SizedBox(height: AppSizes.h12),
                      _buildInfoCard(
                        icon: Icons.verified_outlined,
                        title: 'Compliance Ready',
                        subtitle: 'Aligned with the latest data sovereignty regulations.',
                      ),
                      SizedBox(height: AppSizes.h32),

                      // ── Form ──
                      _buildLabel(context, 'FIRST NAME'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.firstNameController,
                        hintText: 'e.g. John',
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'MIDDLE NAME (OPTIONAL)'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.middleNameController,
                        hintText: 'e.g. Quency',
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'LAST NAME'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.lastNameController,
                        hintText: 'e.g. Doe',
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'EMAIL ADDRESS'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.emailController,
                        hintText: 'john.doe@department.gov',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'PASSWORD'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.passwordController,
                        hintText: '············',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'Minimum 8 characters';
                          return null;
                        },
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'NATIONAL ID'),
                      SizedBox(height: AppSizes.h8),
                      TextFieldForLogin(
                        controller: controller.nationalIdController,
                        hintText: 'ID-0000-0000-00',
                        icon: Icons.badge_outlined,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'ORGANIZATION'),
                      SizedBox(height: AppSizes.h8),
                      controller.isLoadingOrgs
                          ? Container(
                              height: AppSizes.h48,
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(AppSizes.r12),
                              ),
                              child: Center(
                                child: SizedBox(
                                  height: AppSizes.h20,
                                  width: AppSizes.w22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                            )
                          : _buildDropdown(
                              value: controller.selectedOrganizationId,
                              hint: 'Select Organization',
                              items: controller.organizations
                                  .map((org) => DropdownMenuItem<String>(
                                        value: org.id,
                                        child: Text(org.name),
                                      ))
                                  .toList(),
                              onChanged: controller.setOrganization,
                            ),
                      SizedBox(height: AppSizes.h16),

                      _buildLabel(context, 'DEPARTMENT'),
                      SizedBox(height: AppSizes.h8),
                      _buildDropdown(
                        value: controller.selectedDepartment,
                        hint: 'Select Department',
                        items: controller.departments
                            .map((dept) => DropdownMenuItem<String>(
                                  value: dept,
                                  child: Text(dept),
                                ))
                            .toList(),
                        onChanged: controller.setDepartment,
                      ),
                      SizedBox(height: AppSizes.h32),

                      // ── Error Message ──
                      if (controller.errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: AppSizes.h16),
                          padding: EdgeInsets.all(AppSizes.ph14),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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

                      // ── Submit Button ──
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.h56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [AppColors.gradientStart, AppColors.gradientEnd],
                            ),
                            borderRadius: BorderRadius.circular(AppSizes.r16),
                          ),
                          child: ElevatedButton(
                            onPressed: controller.isLoading
                                ? null
                                : () => controller.submitRequest(context),
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
                              height: AppSizes.h22,
                              width: AppSizes.w22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.buttonText,
                              ),
                            )
                                : Text(
                              'Submit Request',
                              style: GoogleFonts.manrope(
                                fontSize: AppSizes.sp16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.h16),

                      // ── Disclaimer ──
                      Container(
                        padding: EdgeInsets.all(AppSizes.ph14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: AppSizes.sp16,
                                color: AppColors.primaryColor),
                            SizedBox(width: AppSizes.w10),
                            Expanded(
                              child: Text(
                                'By clicking Submit, you agree to the government\'s digital security policies and background verification protocols.',
                                style: GoogleFonts.manrope(
                                  fontSize: AppSizes.sp12,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSizes.h40),
                    ],
                  ),
                ),

                // ── Footer ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: AppSizes.h24,
                    horizontal: AppSizes.pw24,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.inputBorder),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFooterLink('PRIVACY\nPOLICY'),
                          _buildFooterLink('SYSTEM\nSTATUS'),
                          _buildFooterLink('HELP\nDESK'),
                        ],
                      ),
                      SizedBox(height: AppSizes.h12),
                      Text(
                        '© 2026 GOVCHAT SECURITY CORE. ALL RIGHTS RESERVED.',
                        style: GoogleFonts.manrope(
                          fontSize: AppSizes.sp9,
                          color: AppColors.hintText,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: AppColors.cardBackground,
      style: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: AppColors.hintText,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      items: items,
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 9,
        color: AppColors.hintText,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }
}