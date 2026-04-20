import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import 'controller/employees_controller.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmployeesController(),
      child: const _EmployeesView(),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _EmployeesView extends StatefulWidget {
  const _EmployeesView();

  @override
  State<_EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<_EmployeesView> {
  // Only local UI state: the text field controller (needs dispose).
  // All filter/search logic lives in EmployeesController.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EmployeesController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          l.employeesTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw24,
            vertical: AppSizes.ph20,
          ),
          child: _buildBody(context, controller),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EmployeesController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(message: controller.errorMessage!);
    }

    // No employees in this org at all
    if (controller.employees.isEmpty) {
      return const _EmptyState();
    }

    final departments = controller.availableDepartments;
    final filtered = controller.filteredEmployees;

    return Column(
      children: [
        // Search bar — delegates query to controller
        _SearchBar(
          controller: _searchCtrl,
          onChanged: controller.setSearch,
        ),
        SizedBox(height: AppSizes.h12),

        // Department chips — shown whenever there is at least one dept value
        if (departments.isNotEmpty)
          _DepartmentFilter(
            departments: departments,
            selected: controller.selectedDepartment,
            onSelect: controller.setDepartment,
          ),
        if (departments.isNotEmpty) SizedBox(height: AppSizes.h16),

        // List or no-results state
        Expanded(
          child: filtered.isEmpty
              ? _SearchEmptyState(
                  query: controller.searchQuery,
                  department: controller.selectedDepartment,
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: AppSizes.ph16),
                  itemBuilder: (_, index) {
                    final employee = filtered[index];
                    return _EmployeeCard(
                      employee: employee,
                      onTap: () => _showEmployeeDetails(
                        context,
                        employee,
                        controller,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Show details bottom sheet (top-level helper) ────────────────────────────

void _showEmployeeDetails(
  BuildContext context,
  EmployeeModel employee,
  EmployeesController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EmployeeDetailsSheet(
      employee: employee,
      controller: controller,
    ),
  );
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontSize: AppSizes.sp14,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name, ID or email',
            hintStyle: GoogleFonts.manrope(
              color: AppColors.hintText,
              fontSize: AppSizes.sp13,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.pw16,
              vertical: AppSizes.ph14,
            ),
            prefixIcon: Padding(
              padding:
                  EdgeInsets.only(left: AppSizes.pw16, right: AppSizes.pw12),
              child: Icon(
                Icons.search_outlined,
                color: AppColors.hintText,
                size: AppSizes.sp18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: AppSizes.sp16,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
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
              borderSide: const BorderSide(color: AppColors.inputFocusBorder),
            ),
          ),
        );
      },
    );
  }
}

// ─── Department filter chips ──────────────────────────────────────────────────

class _DepartmentFilter extends StatelessWidget {
  const _DepartmentFilter({
    required this.departments,
    required this.selected,
    required this.onSelect,
  });

  final List<String> departments;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.h32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _Chip(
            label: 'All',
            isSelected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...departments.map(
            (dept) => Padding(
              padding: EdgeInsets.only(left: AppSizes.w8),
              child: _Chip(
                label: dept,
                isSelected: selected == dept,
                onTap: () => onSelect(dept),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.12)
              : AppColors.sectionBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor.withValues(alpha: 0.4)
                : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected ? AppColors.primaryColor : AppColors.textMuted,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─── Search / filter empty state ──────────────────────────────────────────────

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query, required this.department});

  final String query;
  final String? department;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final hasDept = department != null;

    final String subtitle;
    if (hasQuery && hasDept) {
      subtitle = '"$query" in $department';
    } else if (hasQuery) {
      subtitle = '"$query"';
    } else {
      subtitle = department!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph20),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.circular(AppSizes.r20),
            ),
            child: Icon(
              Icons.search_off_outlined,
              size: AppSizes.h40,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          Text(
            'No results found',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            'No employees match $subtitle',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Employee card ────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});

  final EmployeeModel employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSizes.ph16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r16),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: AppSizes.h32,
              offset: Offset(0, AppSizes.h16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.displayId.isNotEmpty
                            ? employee.displayId
                            : 'EMP-ID MISSING',
                        style: GoogleFonts.manrope(
                          color: AppColors.textTitle,
                          fontSize: AppSizes.sp18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: AppSizes.h6),
                      Text(
                        employee.department,
                        style: GoogleFonts.manrope(
                          color: AppColors.textSubtitle,
                          fontSize: AppSizes.sp12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw12,
                    vertical: AppSizes.ph6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                    border: Border.all(
                      color: AppColors.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: AppSizes.sp14,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(width: AppSizes.w6),
                      Text(
                        'ACTIVE',
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontSize: AppSizes.sp12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSizes.w8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.iconMuted,
                  size: AppSizes.sp20,
                ),
              ],
            ),
            SizedBox(height: AppSizes.ph12),
            _InfoRow(icon: Icons.person_outline, label: employee.name),
            SizedBox(height: AppSizes.h8),
            _InfoRow(icon: Icons.email_outlined, label: employee.email),
            SizedBox(height: AppSizes.h8),
            _InfoRow(
              icon: Icons.apartment_outlined,
              label: employee.organizationName,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Employee details bottom sheet ───────────────────────────────────────────

class _EmployeeDetailsSheet extends StatefulWidget {
  const _EmployeeDetailsSheet({
    required this.employee,
    required this.controller,
  });

  final EmployeeModel employee;
  final EmployeesController controller;

  @override
  State<_EmployeeDetailsSheet> createState() => _EmployeeDetailsSheetState();
}

class _EmployeeDetailsSheetState extends State<_EmployeeDetailsSheet> {
  bool _isDeleting = false;

  Future<void> _handleEdit() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditEmployeeSheet(
        employee: widget.employee,
        controller: widget.controller,
      ),
    );

    if (result == 'saved' && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(employeeName: widget.employee.name),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await widget.controller.deleteEmployee(widget.employee.id!);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.employeeDeactivatedSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw24,
        AppSizes.ph20,
        AppSizes.pw24,
        AppSizes.ph20 + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: AppSizes.w42,
              height: AppSizes.h4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(AppSizes.r4),
              ),
            ),
          ),
          SizedBox(height: AppSizes.ph20),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.displayId.isNotEmpty ? e.displayId : 'EMP-ID MISSING',
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: AppSizes.h4),
                    Text(
                      e.name,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSubtitle,
                        fontSize: AppSizes.sp13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.pw12,
                  vertical: AppSizes.ph6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'ACTIVE',
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontSize: AppSizes.sp11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.ph20),

          // Section: Employee Information
          _sectionLabel('EMPLOYEE INFORMATION'),
          SizedBox(height: AppSizes.h12),
          _DetailRow(icon: Icons.person_outline, label: 'Name', value: e.name),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: e.email,
          ),
          if (e.nationalId.isNotEmpty)
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'National ID',
              value: e.nationalId,
            ),
          SizedBox(height: AppSizes.ph16),

          // Section: Organization Details
          _sectionLabel('ORGANIZATION DETAILS'),
          SizedBox(height: AppSizes.h12),
          _DetailRow(
            icon: Icons.apartment_outlined,
            label: 'Organization',
            value: e.organizationName,
          ),
          _DetailRow(
            icon: Icons.account_tree_outlined,
            label: 'Department',
            value: e.department.isNotEmpty ? e.department : '—',
          ),
          if (e.createdAt != null)
            _DetailRow(
              icon: Icons.event_outlined,
              label: 'Member since',
              value: _formatDate(e.createdAt!),
            ),
          SizedBox(height: AppSizes.ph24),

          // Action buttons
          Row(
            children: [
              // Delete
              Expanded(
                child: SizedBox(
                  height: AppSizes.h48,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _handleDelete,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r12),
                      ),
                    ),
                    icon: _isDeleting
                        ? SizedBox(
                            width: AppSizes.sp14,
                            height: AppSizes.sp14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : Icon(
                            Icons.person_remove_outlined,
                            color: AppColors.error,
                            size: AppSizes.sp16,
                          ),
                    label: Text(
                      'Remove',
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp13,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSizes.w12),
              // Edit
              Expanded(
                child: SizedBox(
                  height: AppSizes.h48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isDeleting ? null : _handleEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AppColors.buttonText,
                        size: AppSizes.sp16,
                      ),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.manrope(
                          color: AppColors.buttonText,
                          fontWeight: FontWeight.w800,
                          fontSize: AppSizes.sp13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textMuted,
        fontSize: AppSizes.sp11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}

// ─── Edit employee bottom sheet ───────────────────────────────────────────────

class _EditEmployeeSheet extends StatefulWidget {
  const _EditEmployeeSheet({
    required this.employee,
    required this.controller,
  });

  final EmployeeModel employee;
  final EmployeesController controller;

  @override
  State<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends State<_EditEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _nationalIdCtrl;

  bool _isLoadingFresh = true;
  bool _isSaving = false;
  String? _fetchWarning;
  String? _errorMessage;

  static const _departments = [
    'IT Department',
    'HR Department',
    'Operations',
    'Security',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.employee.name);
    _deptCtrl = TextEditingController(text: widget.employee.department);
    _nationalIdCtrl = TextEditingController(text: widget.employee.nationalId);
    _fetchFresh();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _nationalIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFresh() async {
    if (widget.employee.id == null) {
      if (mounted) setState(() => _isLoadingFresh = false);
      return;
    }
    try {
      final data =
          await widget.controller.fetchEmployeeForEdit(widget.employee.id!);
      if (!mounted) return;
      _nameCtrl.text = data['name'] ?? _nameCtrl.text;
      _deptCtrl.text = data['department'] ?? _deptCtrl.text;
      _nationalIdCtrl.text = data['nationalId'] ?? _nationalIdCtrl.text;
    } catch (_) {
      if (!mounted) return;
      _fetchWarning = 'Showing cached data — could not sync latest values.';
    } finally {
      if (mounted) setState(() => _isLoadingFresh = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.employee.id == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.updateEmployee(
        widget.employee.id!,
        name: _nameCtrl.text,
        department: _deptCtrl.text,
        nationalId: _nationalIdCtrl.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, 'saved');
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.employeeUpdatedSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw24,
        AppSizes.ph20,
        AppSizes.pw24,
        AppSizes.ph20 + bottomInset + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      child: _isLoadingFresh
          ? _buildLoadingBody()
          : _buildFormBody(),
    );
  }

  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(),
        SizedBox(height: AppSizes.ph40),
        const CircularProgressIndicator(color: AppColors.primaryColor),
        SizedBox(height: AppSizes.ph20),
        Text(
          'Loading latest data…',
          style: GoogleFonts.manrope(
            color: AppColors.textSubtitle,
            fontSize: AppSizes.sp13,
          ),
        ),
        SizedBox(height: AppSizes.ph40),
      ],
    );
  }

  Widget _buildFormBody() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dragHandle(),
            SizedBox(height: AppSizes.ph16),

            // Title
            Text(
              'Edit Employee',
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontSize: AppSizes.sp18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSizes.h4),
            Text(
              widget.employee.displayId.isNotEmpty
                  ? widget.employee.displayId
                  : widget.employee.email,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontSize: AppSizes.sp12,
              ),
            ),
            SizedBox(height: AppSizes.ph20),

            // Fetch warning
            if (_fetchWarning != null) ...[
              Container(
                padding: EdgeInsets.all(AppSizes.ph12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.r10),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: AppSizes.sp14,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: AppSizes.w8),
                    Expanded(
                      child: Text(
                        _fetchWarning!,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontSize: AppSizes.sp11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.ph16),
            ],

            // Name field
            _fieldLabel('NAME'),
            SizedBox(height: AppSizes.h8),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp14,
              ),
              decoration: _inputDecoration('Full name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (RegExp(r'[0-9]').hasMatch(v)) {
                  return 'Name cannot contain numbers';
                }
                return null;
              },
            ),
            SizedBox(height: AppSizes.ph16),

            // Department field
            _fieldLabel('DEPARTMENT'),
            SizedBox(height: AppSizes.h8),
            DropdownButtonFormField<String>(
              initialValue: _departments.contains(_deptCtrl.text)
                  ? _deptCtrl.text
                  : null,
              dropdownColor: AppColors.sectionBackground,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp14,
              ),
              decoration: _inputDecoration('Select department'),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
              items: _departments
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (v) {
                      if (v != null) _deptCtrl.text = v;
                    },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Department is required' : null,
            ),
            SizedBox(height: AppSizes.ph16),

            // National ID field
            _fieldLabel('NATIONAL ID'),
            SizedBox(height: AppSizes.h8),
            TextFormField(
              controller: _nationalIdCtrl,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp14,
              ),
              decoration: _inputDecoration('National ID number'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'National ID is required' : null,
            ),
            SizedBox(height: AppSizes.ph20),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppSizes.ph12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.r10),
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
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: AppSizes.ph16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSizes.h48,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSizes.w12),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.h48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _isSaving
                            ? null
                            : const LinearGradient(
                                colors: [
                                  AppColors.gradientStart,
                                  AppColors.gradientEnd,
                                ],
                              ),
                        color: _isSaving ? AppColors.sectionBackground : null,
                        borderRadius: BorderRadius.circular(AppSizes.r12),
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
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
                                height: AppSizes.h20,
                                width: AppSizes.h20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.buttonText,
                                ),
                              )
                            : Text(
                                'Save',
                                style: GoogleFonts.manrope(
                                  color: AppColors.buttonText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: AppSizes.w42,
        height: AppSizes.h4,
        decoration: BoxDecoration(
          color: AppColors.inputBorder,
          borderRadius: BorderRadius.circular(AppSizes.r4),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        color: AppColors.textMuted,
        fontSize: AppSizes.sp11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: AppColors.hintText,
        fontSize: AppSizes.sp14,
      ),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph14,
      ),
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
        borderSide: const BorderSide(color: AppColors.inputFocusBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.r12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.r12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: GoogleFonts.manrope(
        color: AppColors.error,
        fontSize: AppSizes.sp11,
      ),
    );
  }
}

// ─── Delete confirmation dialog ───────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r16),
      ),
      title: Text(
        'Remove Employee',
        style: GoogleFonts.manrope(
          color: AppColors.textTitle,
          fontSize: AppSizes.sp16,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: RichText(
        text: TextSpan(
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: AppSizes.sp13,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'This will deactivate '),
            TextSpan(
              text: employeeName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const TextSpan(
              text:
                  '\'s account. They will immediately lose access to GovChat.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Remove',
            style: GoogleFonts.manrope(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSizes.w8),
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.circular(AppSizes.r10),
          ),
          child: Icon(icon, size: AppSizes.sp14, color: AppColors.textMuted),
        ),
        SizedBox(width: AppSizes.w12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: AppSizes.sp12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: EdgeInsets.only(bottom: AppSizes.h12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.w8),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.circular(AppSizes.r10),
            ),
            child: Icon(icon, size: AppSizes.sp14, color: AppColors.textMuted),
          ),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: AppSizes.h2),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph20),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.circular(AppSizes.r20),
            ),
            child: Icon(
              Icons.people_outline,
              size: AppSizes.h40,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          Text(
            'No employees yet',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            'Approved employees will appear here.',
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: AppSizes.h40, color: AppColors.error),
          SizedBox(height: AppSizes.ph12),
          Text(
            'Something went wrong',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSubtitle,
                fontSize: AppSizes.sp12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
