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
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/encryption/e2ee_manager.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/Widgets/e2ee_backup_dialogs.dart';
import '../../../../models/employee_model.dart';
import 'employee_reset_password_screen.dart';

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
    final colors = context.colors;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.cardBackground,
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
                  color: colors.textTitle,
                  fontWeight: FontWeight.w800,
                  fontSize: AppSizes.sp18,
                ),
              ),
              SizedBox(height: AppSizes.h16),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.manrope(
                  color: colors.textPrimary,
                  fontSize: AppSizes.sp14,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.sectionBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                    borderSide: BorderSide(color: colors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                    borderSide: BorderSide(color: colors.inputBorder),
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
                        side: BorderSide(color: colors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: AppSizes.ph14),
                      ),
                      child: Text(
                        l.cancelButton,
                        style: GoogleFonts.manrope(
                          color: colors.textMuted,
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
    final themeProvider = context.watch<ThemeProvider>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: colors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l.profileTitle,
          style: GoogleFonts.manrope(
            color: colors.textPrimary,
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
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
                                  ? SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: colors.textPrimary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.camera_alt_rounded,
                                      color: colors.textPrimary,
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
                                      color: colors.textTitle,
                                      fontSize: AppSizes.sp18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(width: AppSizes.w6),
                                Icon(
                                  Icons.edit_outlined,
                                  color: colors.textMuted,
                                  size: AppSizes.sp14,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSizes.h4),
                          Text(
                            widget.employee.email,
                            style: GoogleFonts.manrope(
                              color: colors.textMuted,
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.employeeInfoSection,
                      style: GoogleFonts.manrope(
                        color: colors.textMuted,
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
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
                            color: colors.textTitle,
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
                          color: colors.sectionBackground,
                          borderRadius: BorderRadius.circular(AppSizes.r20),
                          border: Border.all(color: colors.inputBorder),
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

              // ── Theme Switcher Card ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph16),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: AppColors.primaryColor,
                          size: AppSizes.sp20,
                        ),
                        SizedBox(width: AppSizes.w12),
                        Text(
                          l.themeLabel,
                          style: GoogleFonts.manrope(
                            color: colors.textTitle,
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSizes.h12),
                    Row(
                      children: [
                        _ThemeOption(
                          label: l.themeDark,
                          icon: Icons.dark_mode_outlined,
                          selected:
                              themeProvider.themeMode == ThemeMode.dark,
                          onTap: () => themeProvider.setTheme(ThemeMode.dark),
                        ),
                        SizedBox(width: AppSizes.w8),
                        _ThemeOption(
                          label: l.themeLight,
                          icon: Icons.light_mode_outlined,
                          selected:
                              themeProvider.themeMode == ThemeMode.light,
                          onTap: () => themeProvider.setTheme(ThemeMode.light),
                        ),
                        SizedBox(width: AppSizes.w8),
                        _ThemeOption(
                          label: l.themeSystem,
                          icon: Icons.brightness_auto_outlined,
                          selected:
                              themeProvider.themeMode == ThemeMode.system,
                          onTap: () =>
                              themeProvider.setTheme(ThemeMode.system),
                        ),
                      ],
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
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
                                  color: colors.textTitle,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppSizes.sp14,
                                ),
                              ),
                              SizedBox(height: AppSizes.h2),
                              Text(
                                l.changePasswordDescription,
                                style: GoogleFonts.manrope(
                                  color: colors.textMuted,
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
                              builder: (_) => EmployeeResetPasswordScreen(
                                uid: widget.employee.id ?? '',
                                email: widget.employee.email,
                                phoneNumber: widget.employee.phoneNumber,
                                phoneVerified: widget.employee.phoneVerified,
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
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
                                  color: colors.textTitle,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppSizes.sp14,
                                ),
                              ),
                              SizedBox(height: AppSizes.h2),
                              Text(
                                l.encryptionKeyBackupDescription,
                                style: GoogleFonts.manrope(
                                  color: colors.textMuted,
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
                                ? colors.inputBorder
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
                                ? colors.textMuted
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
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                  border: Border.all(color: colors.inputBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.sessionControlsSection,
                      style: GoogleFonts.manrope(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: AppSizes.h10),
                    Text(
                      l.endSessionDescription,
                      style: GoogleFonts.manrope(
                        color: colors.textSubtitle,
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
                        icon: Icon(
                          Icons.logout_rounded,
                          color: colors.textPrimary,
                        ),
                        label: Text(
                          l.signOutButton,
                          style: GoogleFonts.manrope(
                            color: colors.textPrimary,
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
  final colors = context.colors;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: colors.cardBackground,
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
                    color: colors.textTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: AppSizes.sp18,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                Text(
                  l.signOutConfirm,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: colors.textMuted,
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
                          side: BorderSide(color: colors.inputBorder),
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
                            color: colors.textMuted,
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
                            color: colors.textPrimary,
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

// ── Theme option chip ──
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: AppSizes.ph10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryColor.withValues(alpha: 0.12)
                : colors.sectionBackground,
            borderRadius: BorderRadius.circular(AppSizes.r12),
            border: Border.all(
              color: selected ? AppColors.primaryColor : colors.inputBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primaryColor : colors.textMuted,
                size: AppSizes.sp18,
              ),
              SizedBox(height: AppSizes.h4),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: selected ? AppColors.primaryColor : colors.textMuted,
                  fontSize: AppSizes.sp11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final colors = context.colors;
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
                    color: colors.textMuted,
                    fontSize: AppSizes.sp10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSizes.h2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: GoogleFonts.manrope(
                    color: colors.textTitle,
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
    return Divider(
      color: context.colors.inputBorder,
      height: 1,
      thickness: 1,
    );
  }
}
