import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/encryption/e2ee_manager.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/App_color.dart';
import '../../../../core/Widgets/e2ee_backup_dialogs.dart';
import '../../../../models/employee_model.dart';
import 'verification_code_screen.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  late String _avatarUrl;
  late String _name;
  bool _uploading = false;
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.employee.avatarUrl;
    _name = widget.employee.name;
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final employeeId = widget.employee.id ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(employeeId)
          .child('avatar_$timestamp.jpg');

      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await FirebaseService.instance.firestore
          .collection('employees')
          .doc(employeeId)
          .update({'avatarUrl': url});

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _uploading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update avatar',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _backupEncryptionKey() async {
    final l = AppLocalizations.of(context)!;
    final uid = widget.employee.id ?? '';
    if (uid.isEmpty) return;

    if (!mounted) return;
    final password = await showE2eeBackupDialog(context);
    if (password == null || !mounted) return;

    setState(() => _backingUp = true);

    try {
      await E2eeManager.createBackup(uid: uid, password: password);
      // Cache password so auto-refresh can update the backup when new
      // conversation keys are derived during this session.
      E2eeManager.setBackupPassword(password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.backupSuccessMessage,
              style: GoogleFonts.manrope(color: AppColors.buttonText),
            ),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.backupFailedMessage,
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final l = AppLocalizations.of(context)!;

    final newName = await showDialog<String>(
      context: context,
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
              Text(
                l.editNameTitle,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                  fontSize: AppSizes.sp18,
                ),
              ),
              SizedBox(height: AppSizes.h16),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: AppSizes.sp14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.sectionBackground,
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
                    borderSide: const BorderSide(color: AppColors.primaryColor),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.h24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: AppSizes.ph14),
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
                      onPressed: () {
                        final value = controller.text.trim();
                        if (value.isNotEmpty) Navigator.pop(ctx, value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: AppSizes.ph14),
                      ),
                      child: Text(
                        l.saveButton,
                        style: GoogleFonts.manrope(
                          color: AppColors.buttonText,
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
    );

    if (newName == null || newName == _name) return;

    try {
      final employeeId = widget.employee.id ?? '';
      await FirebaseService.instance.firestore
          .collection('employees')
          .doc(employeeId)
          .update({'name': newName});

      if (mounted) setState(() => _name = newName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update name',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l.profileTitle,
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
                    GestureDetector(
                      onTap: _uploading ? null : _pickAndUploadAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(AppSizes.r12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _avatarUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _avatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, url) => const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                    errorWidget: (_, url, error) => const Icon(
                                      Icons.person_rounded,
                                      color: AppColors.primaryColor,
                                      size: 28,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primaryColor,
                                    size: 28,
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.r6,
                                ),
                              ),
                              child: _uploading
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      color: AppColors.textPrimary,
                                      size: 12,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSizes.w12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _editName,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _name,
                                    style: GoogleFonts.manrope(
                                      color: AppColors.textTitle,
                                      fontSize: AppSizes.sp18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSizes.w6),
                                Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.textMuted,
                                  size: AppSizes.sp14,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSizes.h4),
                          Text(
                            widget.employee.email,
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
                      l.employeeInfoSection,
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
                      label: l.organizationField,
                      value: widget.employee.organizationName,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.workspaces_outlined,
                      label: l.departmentField,
                      value: widget.employee.department,
                    ),
                    _Divider(),
                    _InfoRow(
                      icon: Icons.tag_outlined,
                      label: l.employeeIdField,
                      value: widget.employee.displayId.isNotEmpty
                          ? widget.employee.displayId
                          : '—',
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
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp20,
                        ),
                        SizedBox(width: AppSizes.w12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.changePasswordButton,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textTitle,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppSizes.sp14,
                                ),
                              ),
                              SizedBox(height: AppSizes.h2),
                              Text(
                                l.changePasswordDescription,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted,
                                  fontSize: AppSizes.sp11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSizes.ph16),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.h44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VerificationCodeScreen(
                                uid: widget.employee.id ?? '',
                                email: widget.employee.email,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                        ),
                        icon: Icon(
                          Icons.lock_reset_outlined,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp18,
                        ),
                        label: Text(
                          l.changePasswordButton,
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppSizes.ph16),

              // ── Encryption Key Backup Card ──
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
                    Row(
                      children: [
                        Icon(
                          Icons.key_outlined,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp20,
                        ),
                        SizedBox(width: AppSizes.w12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.encryptionKeySection,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textTitle,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppSizes.sp14,
                                ),
                              ),
                              SizedBox(height: AppSizes.h2),
                              Text(
                                l.encryptionKeyBackupDescription,
                                style: GoogleFonts.manrope(
                                  color: AppColors.textMuted,
                                  fontSize: AppSizes.sp11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSizes.ph16),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.h44,
                      child: OutlinedButton.icon(
                        onPressed: _backingUp ? null : _backupEncryptionKey,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _backingUp
                                ? AppColors.inputBorder
                                : AppColors.primaryColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                        ),
                        icon: _backingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryColor,
                                ),
                              )
                            : Icon(
                                Icons.backup_outlined,
                                color: AppColors.primaryColor,
                                size: AppSizes.sp18,
                              ),
                        label: Text(
                          l.backupKeyButton,
                          style: GoogleFonts.manrope(
                            color: _backingUp
                                ? AppColors.textMuted
                                : AppColors.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp13,
                          ),
                        ),
                      ),
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

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l) async {
    final shouldLogout = await _showLogoutDialog(context, l);
    if (!shouldLogout || !context.mounted) return;
    await SessionManager.instance.logout(context);
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
