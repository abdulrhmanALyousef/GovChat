import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../constants/app_size.dart';
import '../services/encryption/e2ee_backup_service.dart';
import '../services/encryption/e2ee_manager.dart';
import '../theme/App_color.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Shows a dialog for creating a key backup.
///
/// Returns the user's chosen password on confirmation, or `null` if cancelled.
Future<String?> showE2eeBackupDialog(BuildContext context) {
  final theme = Theme.of(context);
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: const _BackupPasswordDialog(),
    ),
  );
}

/// Shows a dialog for restoring keys from a Firestore backup.
///
/// The dialog handles wrong-password retries with inline error messages.
/// Returns a [BackupManifest] on success (contains identity key + all
/// conversation keys), or `null` if the user taps "Skip".
Future<BackupManifest?> showE2eeRestoreDialog(BuildContext context, String uid) {
  final theme = Theme.of(context);
  return showDialog<BackupManifest>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: _RestorePasswordDialog(uid: uid),
    ),
  );
}

// ── Backup Dialog ─────────────────────────────────────────────────────────────

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final pw = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pw.length < 8) {
      setState(() => _error = l.passwordTooShort);
      return;
    }
    if (pw != confirm) {
      setState(() => _error = l.passwordsDoNotMatch);
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: context.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r20),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw24,
        vertical: AppSizes.ph24,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.ph8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                  ),
                  child: Icon(
                    Icons.lock_outlined,
                    color: AppColors.primaryColor,
                    size: AppSizes.sp20,
                  ),
                ),
                SizedBox(width: AppSizes.w12),
                Expanded(
                  child: Text(
                    l.backupKeyPasswordDialogTitle,
                    style: GoogleFonts.manrope(
                      color: context.colors.textTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: AppSizes.sp16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.h12),
            Text(
              l.backupKeyPasswordDialogDescription,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp12,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppSizes.h20),
            // Password field
            _PasswordField(
              controller: _passwordCtrl,
              hint: l.backupPasswordHint,
              obscure: _obscure1,
              onToggle: () => setState(() => _obscure1 = !_obscure1),
              onChanged: (_) => setState(() => _error = null),
            ),
            SizedBox(height: AppSizes.h12),
            // Confirm field
            _PasswordField(
              controller: _confirmCtrl,
              hint: l.confirmBackupPasswordHint,
              obscure: _obscure2,
              onToggle: () => setState(() => _obscure2 = !_obscure2),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              SizedBox(height: AppSizes.h8),
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: AppSizes.sp12,
                ),
              ),
            ],
            SizedBox(height: AppSizes.h24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizes.ph12,
                          horizontal: AppSizes.pw8,
                        ),
                      ),
                      child: Text(
                        l.cancelButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: context.colors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.sp13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.w12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizes.ph12,
                          horizontal: AppSizes.pw8,
                        ),
                      ),
                      child: Text(
                        l.backupKeyButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: AppColors.buttonText,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp13,
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
    );
  }
}

// ── Restore Dialog ────────────────────────────────────────────────────────────

class _RestorePasswordDialog extends StatefulWidget {
  const _RestorePasswordDialog({required this.uid});

  final String uid;

  @override
  State<_RestorePasswordDialog> createState() => _RestorePasswordDialogState();
}

class _RestorePasswordDialogState extends State<_RestorePasswordDialog> {
  final _passwordCtrl = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final pw = _passwordCtrl.text.trim();
    if (pw.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final manifest = await E2eeBackupService.restoreFromBackup(
        uid: widget.uid,
        password: pw,
      );

      // Cache the password in-memory so the backup can be auto-refreshed
      // when new conversation keys are derived during this session.
      E2eeManager.setBackupPassword(pw);

      if (mounted) Navigator.pop(context, manifest);
    } on E2eeBackupWrongPasswordException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l.restoreFailedWrongPassword;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l.restoreFailedMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: context.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r20),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw24,
        vertical: AppSizes.ph24,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.ph8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                  ),
                  child: Icon(
                    Icons.restore_outlined,
                    color: AppColors.primaryColor,
                    size: AppSizes.sp20,
                  ),
                ),
                SizedBox(width: AppSizes.w12),
                Expanded(
                  child: Text(
                    l.restoreKeyPasswordDialogTitle,
                    style: GoogleFonts.manrope(
                      color: context.colors.textTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: AppSizes.sp16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.h12),
            Text(
              l.restoreKeyPasswordDialogDescription,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp12,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppSizes.h20),
            _PasswordField(
              controller: _passwordCtrl,
              hint: l.backupPasswordHint,
              obscure: _obscure,
              onToggle: () => setState(() => _obscure = !_obscure),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              SizedBox(height: AppSizes.h8),
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: AppSizes.sp12,
                ),
              ),
            ],
            SizedBox(height: AppSizes.h24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizes.ph12,
                          horizontal: AppSizes.pw8,
                        ),
                      ),
                      child: Text(
                        l.skipRestoreButton,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: context.colors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.sp13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.w12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppSizes.ph12,
                          horizontal: AppSizes.pw8,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Text(
                              l.restoreKeyButton,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: AppColors.buttonText,
                                fontWeight: FontWeight.w700,
                                fontSize: AppSizes.sp13,
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
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: GoogleFonts.manrope(
        color: context.colors.textPrimary,
        fontSize: AppSizes.sp14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: context.colors.textMuted,
          fontSize: AppSizes.sp13,
        ),
        filled: true,
        fillColor: context.colors.sectionBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: BorderSide(color: context.colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: BorderSide(color: context.colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          borderSide: const BorderSide(color: AppColors.primaryColor),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: context.colors.textMuted,
            size: AppSizes.sp18,
          ),
        ),
      ),
    );
  }
}