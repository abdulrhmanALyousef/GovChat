import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/unified_group.dart';
import 'controller/admin_groups_controller.dart';
import 'group_chat_screen.dart';

class AdminGroupsScreen extends StatelessWidget {
  const AdminGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminGroupsController(),
      child: const _GroupsView(),
    );
  }
}

class _GroupsView extends StatelessWidget {
  const _GroupsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminGroupsController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l.projectGroupsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryColor),
            tooltip: l.createGroupButton,
            onPressed: controller.isLoading
                ? null
                : () => _showCreateGroupSheet(context, controller, l),
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            )
          : controller.errorMessage != null
              ? _ErrorState(message: controller.errorMessage!)
              : controller.unifiedGroups.isEmpty
                  ? _EmptyState(l: l)
                  : _GroupList(
                      groups: controller.unifiedGroups,
                      controller: controller,
                      l: l,
                    ),
    );
  }

  Future<void> _showCreateGroupSheet(
    BuildContext context,
    AdminGroupsController controller,
    AppLocalizations l,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: _CreateGroupSheet(l: l),
      ),
    );
  }
}

// ─── Group list ───────────────────────────────────────────────────────────────

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.controller,
    required this.l,
  });
  final List<UnifiedGroup> groups;
  final AdminGroupsController controller;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(AppSizes.pw16),
      itemCount: groups.length,
      separatorBuilder: (context, index) => SizedBox(height: AppSizes.h8),
      itemBuilder: (_, i) => _GroupCard(
        group: groups[i],
        controller: controller,
        l: l,
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.controller,
    required this.l,
  });
  final UnifiedGroup group;
  final AdminGroupsController controller;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(group.type);
    final typeIcon = _typeIcon(group.type);
    final typeLabel = _typeLabel(l, group.type);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminGroupChatScreen(group: group),
        ),
      ),
      child: Container(
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
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.r12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            SizedBox(width: AppSizes.w12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: GoogleFonts.manrope(
                      color: AppColors.textTitle,
                      fontWeight: FontWeight.w700,
                      fontSize: AppSizes.sp14,
                    ),
                  ),
                  SizedBox(height: AppSizes.h4),
                  Row(
                    children: [
                      _TypeBadge(label: typeLabel, color: typeColor),
                      SizedBox(width: AppSizes.w8),
                      Text(
                        l.membersCount(group.memberCount),
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted,
                          fontSize: AppSizes.sp11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (group.isDeletable)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                onPressed: () =>
                    _confirmDelete(context, controller, group, l),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.navUnselected),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminGroupsController controller,
    UnifiedGroup group,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          l.deleteGroupConfirmTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w700,
            fontSize: AppSizes.sp16,
          ),
        ),
        content: Text(
          l.deleteGroupConfirmMessage,
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: AppSizes.sp14,
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
              l.deleteUppercase,
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await controller.deleteGroup(group);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.cannotDeleteSystemGroup),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'company':
        return const Color(0xFF60A5FA);
      case 'department':
        return const Color(0xFF34D399);
      default:
        return AppColors.primaryColor;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'company':
        return Icons.business_outlined;
      case 'department':
        return Icons.group_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  String _typeLabel(AppLocalizations l, String type) {
    switch (type) {
      case 'company':
        return l.companyGroupLabel;
      case 'department':
        return l.departmentGroupLabel;
      default:
        return l.projectGroupLabel;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw6,
        vertical: AppSizes.ph4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.r4),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          color: color,
          fontSize: AppSizes.sp9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Create group bottom sheet ────────────────────────────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.l});
  final AppLocalizations l;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Set<String> _selectedIds = {};
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminGroupsController>();
    final l = widget.l;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.pw24,
        right: AppSizes.pw24,
        top: AppSizes.ph24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.ph24,
      ),
      child: Form(
        key: _formKey,
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
              l.createGroupTitle,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp18,
              ),
            ),
            SizedBox(height: AppSizes.ph16),
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: l.groupNameLabel,
                hintText: l.groupNameHint,
                labelStyle: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp12,
                ),
                hintStyle: GoogleFonts.manrope(color: AppColors.hintText),
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
                  borderSide:
                      const BorderSide(color: AppColors.inputFocusBorder),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.groupNameRequired : null,
            ),
            SizedBox(height: AppSizes.ph16),
            Text(
              l.selectMembersLabel,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: AppSizes.sp12,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: AppSizes.h8),
            controller.employees.isEmpty
                ? Text(
                    l.noEmployeesAvailable,
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: AppSizes.sp13,
                    ),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: AppSizes.h200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.employees.length,
                      itemBuilder: (_, i) {
                        final emp = controller.employees[i];
                        final selected = _selectedIds.contains(emp.id);
                        return CheckboxListTile(
                          dense: true,
                          value: selected,
                          activeColor: AppColors.primaryColor,
                          checkColor: AppColors.scaffoldBackground,
                          title: Text(
                            emp.name,
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontSize: AppSizes.sp13,
                            ),
                          ),
                          subtitle: Text(
                            emp.displayId,
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                              fontSize: AppSizes.sp11,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(emp.id!);
                              } else {
                                _selectedIds.remove(emp.id);
                              }
                            });
                          },
                        );
                      },
                    ),
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
            SizedBox(height: AppSizes.ph16),
            SizedBox(
              width: double.infinity,
              height: AppSizes.h48,
              child: ElevatedButton(
                onPressed: _isCreating
                    ? null
                    : () => _submit(context, controller, l),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                  ),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(
                        color: AppColors.scaffoldBackground,
                        strokeWidth: 2,
                      )
                    : Text(
                        l.createGroupButton,
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
    );
  }

  Future<void> _submit(
    BuildContext context,
    AdminGroupsController controller,
    AppLocalizations l,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedIds.isEmpty) {
      setState(() => _error = l.atLeastOneMember);
      return;
    }
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      await controller.createGroup(
        name: _nameController.text.trim(),
        memberIds: _selectedIds.toList(),
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.groupCreatedSuccess)),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCreating = false;
      });
    }
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.pw24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: AppColors.navUnselected),
            SizedBox(height: AppSizes.ph16),
            Text(
              l.noGroupsYet,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w700,
                fontSize: AppSizes.sp16,
              ),
            ),
            SizedBox(height: AppSizes.h8),
            Text(
              l.noGroupsDesc,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.manrope(
          color: AppColors.error,
          fontSize: AppSizes.sp14,
        ),
      ),
    );
  }
}
