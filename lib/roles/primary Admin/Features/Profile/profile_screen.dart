import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/activity_log_service.dart';
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSizes.pw24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Identity Card ──────────────────────────────────
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

              // ── Language Switcher ──────────────────────────────
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
                      onTap: localeProvider.toggleLocale,
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

              // ── Change Password ────────────────────────────────
              const _ChangePasswordCard(),
              SizedBox(height: AppSizes.ph16),

              // ── Session Controls ───────────────────────────────
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
          builder: (ctx) => AlertDialog(
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
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l.cancelUppercase,
                  style: GoogleFonts.manrope(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l.logoutUppercase,
                  style: GoogleFonts.manrope(color: AppColors.primaryColor),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout || !context.mounted) return;
    await SessionManager.instance.logout(context);
  }
}

// ── Change Password Card ──────────────────────────────────────────────

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSaving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  bool _isExpanded = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppSizes.r16),
            child: Padding(
              padding: EdgeInsets.all(AppSizes.ph16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSizes.ph8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.r8),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF818CF8),
                      size: 18,
                    ),
                  ),
                  SizedBox(width: AppSizes.w12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.changePasswordSection,
                          style: GoogleFonts.manrope(
                            color: AppColors.textTitle,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                        Text(
                          l.changePasswordCardDescription,
                          style: GoogleFonts.manrope(
                            color: AppColors.textSubtitle,
                            fontSize: AppSizes.sp11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      color: AppColors.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable Form ──────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildForm(context, l),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        0,
        AppSizes.pw16,
        AppSizes.ph16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Divider(color: AppColors.inputBorder, height: 1),
            SizedBox(height: AppSizes.ph12),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSizes.r8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontSize: AppSizes.sp12,
                  ),
                ),
              ),
              SizedBox(height: AppSizes.ph12),
            ],

            _PasswordField(
              controller: _currentCtrl,
              label: l.currentPasswordLabelField,
              hint: l.currentPasswordHint,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) => (v == null || v.isEmpty)
                  ? l.currentPasswordIsRequired
                  : null,
            ),
            SizedBox(height: AppSizes.ph12),

            _PasswordField(
              controller: _newCtrl,
              label: l.newPasswordLabelProfile,
              hint: l.newPasswordHintProfile,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return l.requiredField;
                if (v.length < 8) return l.ruleMinChars;
                if (!v.contains(RegExp(r'[A-Z]'))) return l.ruleUppercase;
                if (!v.contains(RegExp(r'[a-z]'))) return l.ruleLowercase;
                if (!v.contains(RegExp(r'[0-9]'))) return l.ruleNumber;
                if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                  return l.ruleSpecialChar;
                }
                return null;
              },
            ),
            SizedBox(height: AppSizes.ph12),

            _PasswordField(
              controller: _confirmCtrl,
              label: l.confirmNewPasswordLabel,
              hint: l.confirmNewPasswordHint,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) => v != _newCtrl.text
                  ? l.passwordsDoNotMatch
                  : null,
            ),
            SizedBox(height: AppSizes.ph16),

            SizedBox(
              width: double.infinity,
              height: AppSizes.h48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSaving
                        ? [
                            AppColors.gradientStart.withValues(alpha: 0.5),
                            AppColors.gradientEnd.withValues(alpha: 0.5),
                          ]
                        : const [
                            AppColors.gradientStart,
                            AppColors.gradientEnd,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.buttonText,
                          ),
                        )
                      : Text(
                          l.changePasswordAction,
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
    );
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final l = AppLocalizations.of(context)!;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text);

      // Log the password change (fire-and-forget)
      ActivityLogService.instance.log(
        action: ActivityLogService.actionPasswordChanged,
        actorId: user.uid,
        actorEmail: user.email!,
        actorRole: 'primary_admin',
      );

      if (!mounted) return;

      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() => _isExpanded = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.passwordChangedSuccessfully),
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage =
            (e.code == 'wrong-password' || e.code == 'invalid-credential')
                ? l.incorrectCurrentPassword
                : (e.message ?? l.failedToUpdatePassword);
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }

    if (mounted) setState(() => _isSaving = false);
  }
}

// ── Password Field Widget ─────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: AppSizes.h6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontSize: AppSizes.sp13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: AppColors.hintText,
              fontSize: AppSizes.sp13,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.iconMuted,
                size: 18,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.pw16,
              vertical: AppSizes.ph14,
            ),
          ),
        ),
      ],
    );
  }
}
