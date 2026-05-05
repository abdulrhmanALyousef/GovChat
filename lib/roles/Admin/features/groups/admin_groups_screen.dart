import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/project_group_model.dart';
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
              : controller.groups.isEmpty
                  ? _EmptyState(l: l)
                  : _GroupList(groups: controller.groups, l: l),
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
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l.groupNameRequired
                  : null,
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
                onPressed: _isCreating ? null : () => _submit(context, controller, l),
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

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.l});
  final List<ProjectGroupModel> groups;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(AppSizes.pw16),
      itemCount: groups.length,
      separatorBuilder: (context, index) => SizedBox(height: AppSizes.h8),
      itemBuilder: (_, i) => _GroupCard(group: groups[i], l: l),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.l});
  final ProjectGroupModel group;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.r12),
              ),
              child: const Icon(
                Icons.group_outlined,
                color: AppColors.primaryColor,
                size: 22,
              ),
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
                  Text(
                    l.membersCount(group.memberIds.length),
                    style: GoogleFonts.manrope(
                      color: AppColors.textMuted,
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
    );
  }
}

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
            Icon(
              Icons.group_outlined,
              size: 64,
              color: AppColors.navUnselected,
            ),
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
