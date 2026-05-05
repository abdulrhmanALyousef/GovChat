import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import 'controller/admin_change_password_controller.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          l.profileTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
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
                            l.adminSession,
                            style: GoogleFonts.manrope(
                              color: AppColors.textTitle,
                              fontSize: AppSizes.sp18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: AppSizes.h6),
                          Text(
                            l.adminSessionDescription,
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

              // ── Change Password Card ──
              GestureDetector(
                onTap: () => _showChangePasswordSheet(context, l),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSizes.ph16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.r16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSizes.ph8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                        ),
                        child: Icon(
                          Icons.lock_reset_outlined,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp20,
                        ),
                      ),
                      SizedBox(width: AppSizes.w12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.changePasswordFromProfile,
                              style: GoogleFonts.manrope(
                                color: AppColors.textTitle,
                                fontWeight: FontWeight.w600,
                                fontSize: AppSizes.sp14,
                              ),
                            ),
                            SizedBox(height: AppSizes.h4),
                            Text(
                              l.changePasswordDescription,
                              style: GoogleFonts.manrope(
                                color: AppColors.textSubtitle,
                                fontSize: AppSizes.sp11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.navUnselected,
                      ),
                    ],
                  ),
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
                      l.endSessionDescription,
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
                        onPressed: () => _confirmLogout(context, l),
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
                          l.signOutButton,
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

  Future<void> _showChangePasswordSheet(
      BuildContext context, AppLocalizations l) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      builder: (_) => ChangeNotifierProvider(
        create: (_) => AdminChangePasswordController(),
        child: _ChangePasswordSheet(l: l),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l) async {
    final shouldLogout = await _showLogoutDialog(context, l);
    if (!shouldLogout || !context.mounted) return;
    await SessionManager.instance.logout(context);
  }
}

class _ChangePasswordSheet extends StatelessWidget {
  const _ChangePasswordSheet({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminChangePasswordController>();

    if (ctrl.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.passwordChangedSuccess)),
        );
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.pw24,
        right: AppSizes.pw24,
        top: AppSizes.ph24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.ph24,
      ),
      child: Form(
        key: ctrl.formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(AppSizes.r4),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.ph16),
              Text(
                l.changePasswordFromProfile,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                  fontSize: AppSizes.sp18,
                ),
              ),
              SizedBox(height: AppSizes.ph16),
              _PasswordField(
                controller: ctrl.currentPasswordCtrl,
                label: l.currentPasswordLabel,
                hint: l.currentPasswordHint,
                validator: (v) => (v == null || v.isEmpty)
                    ? l.currentPasswordRequired
                    : null,
              ),
              SizedBox(height: AppSizes.ph12),
              _PasswordField(
                controller: ctrl.newPasswordCtrl,
                label: l.newPasswordLabel,
                hint: l.newPasswordLabel,
                onChanged: ctrl.onNewPasswordChanged,
                validator: (v) {
                  if (v == null || v.isEmpty) return l.requiredField;
                  if (!ctrl.isPasswordStrong) return l.ruleMinChars;
                  return null;
                },
              ),
              SizedBox(height: AppSizes.h8),
              _PasswordRules(ctrl: ctrl, l: l),
              SizedBox(height: AppSizes.ph12),
              _PasswordField(
                controller: ctrl.confirmPasswordCtrl,
                label: l.confirmPasswordLabel,
                hint: l.confirmPasswordLabel,
                validator: (v) {
                  if (v != ctrl.newPasswordCtrl.text) {
                    return l.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
              if (ctrl.errorMessage != null) ...[
                SizedBox(height: AppSizes.h8),
                Text(
                  ctrl.errorMessage == 'wrongCurrentPassword'
                      ? l.wrongCurrentPassword
                      : ctrl.errorMessage!,
                  style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontSize: AppSizes.sp12,
                  ),
                ),
              ],
              SizedBox(height: AppSizes.ph16),
              SizedBox(
                width: double.infinity,
                height: AppSizes.h48,
                child: ElevatedButton(
                  onPressed: ctrl.isLoading ? null : ctrl.changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                    ),
                  ),
                  child: ctrl.isLoading
                      ? const CircularProgressIndicator(
                          color: AppColors.scaffoldBackground,
                          strokeWidth: 2,
                        )
                      : Text(
                          l.updatePasswordButton,
                          style: GoogleFonts.manrope(
                            color: AppColors.scaffoldBackground,
                            fontWeight: FontWeight.w800,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.ctrl, required this.l});
  final AdminChangePasswordController ctrl;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Rule(ok: ctrl.hasMinLength, text: l.ruleMinChars),
        _Rule(ok: ctrl.hasUppercase, text: l.ruleUppercase),
        _Rule(ok: ctrl.hasLowercase, text: l.ruleLowercase),
        _Rule(ok: ctrl.hasNumber, text: l.ruleNumber),
        _Rule(ok: ctrl.hasSpecialChar, text: l.ruleSpecialChar),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.h4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: ok ? AppColors.primaryColor : AppColors.navUnselected,
          ),
          SizedBox(width: AppSizes.w6),
          Text(
            text,
            style: GoogleFonts.manrope(
              color: ok ? AppColors.primaryColor : AppColors.textMuted,
              fontSize: AppSizes.sp11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      validator: widget.validator,
      style: GoogleFonts.manrope(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: GoogleFonts.manrope(
          color: AppColors.textMuted,
          fontSize: AppSizes.sp12,
        ),
        hintStyle: GoogleFonts.manrope(color: AppColors.hintText),
        filled: true,
        fillColor: AppColors.inputFill,
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.navUnselected,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.inputFocusBorder),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

Future<bool> _showLogoutDialog(BuildContext context, AppLocalizations l) async {
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
                  l.signOutButton,
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: AppSizes.sp18,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                Text(
                  l.signOutConfirm,
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
                          l.cancelButton,
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
                          l.signOutButton,
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
