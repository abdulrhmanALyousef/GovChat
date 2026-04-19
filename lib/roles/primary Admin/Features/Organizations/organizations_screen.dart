import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/organization_model.dart';
import 'controllers/organizations_management_controller.dart';
import 'create_organization_screen.dart';

class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrganizationsManagementController(),
      child: const _OrganizationsView(),
    );
  }
}

class _OrganizationsView extends StatelessWidget {
  const _OrganizationsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrganizationsManagementController>();
    _showMessages(context, controller);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw24,
            vertical: AppSizes.ph20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Organizations',
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: AppSizes.w200),
                    child: SizedBox(
                      height: AppSizes.h44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateOrganizationScreen(),
                            ),
                          );
                          if (!context.mounted) return;
                          await context
                              .read<OrganizationsManagementController>()
                              .loadOrganizations();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('CREATE ORGANIZATION'),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.h8),
              Text(
                'View, update, and manage organizations securely.',
                style: GoogleFonts.manrope(
                  color: AppColors.textSubtitle,
                  fontSize: AppSizes.sp12,
                ),
              ),
              SizedBox(height: AppSizes.ph16),
              Expanded(
                child: SizedBox.expand(child: _buildBody(context, controller)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    OrganizationsManagementController controller,
  ) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(
        message: controller.errorMessage!,
        onRetry: controller.loadOrganizations,
      );
    }

    if (controller.organizations.isEmpty) {
      return _EmptyState(
        onCreate: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOrganizationScreen()),
          );
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: controller.loadOrganizations,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: controller.organizations.length,
        separatorBuilder: (_, index) => SizedBox(height: AppSizes.ph12),
        itemBuilder: (context, index) {
          final organization = controller.organizations[index];
          return _OrganizationCard(
            organization: organization,
            onTap: () => _showOrganizationDetails(context, organization),
          );
        },
      ),
    );
  }

  void _showMessages(
    BuildContext context,
    OrganizationsManagementController controller,
  ) {
    if (controller.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.successMessage!),
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
        controller.clearMessages();
      });
    }

    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        controller.clearMessages();
      });
    }
  }

  Future<void> _showOrganizationDetails(
    BuildContext context,
    OrganizationModel organization,
  ) async {
    final controller = context.read<OrganizationsManagementController>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
      ),
      builder: (_) => _OrganizationDetailsSheet(
        organization: organization,
        controller: controller,
      ),
    );

    if (!context.mounted) return;
    await controller.loadOrganizations();
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({required this.organization, required this.onTap});

  final OrganizationModel organization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.r16),
      child: Container(
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
                Expanded(
                  child: Text(
                    organization.name,
                    style: GoogleFonts.manrope(
                      color: AppColors.textTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: AppSizes.sp16,
                    ),
                  ),
                ),
                _StatusChip(status: organization.status),
              ],
            ),
            SizedBox(height: AppSizes.h8),
            _InfoText(label: 'ADMIN', value: organization.adminEmail),
            SizedBox(height: AppSizes.h6),
            _InfoText(label: 'CITY', value: organization.city),
            SizedBox(height: AppSizes.h6),
            _InfoText(
              label: 'CREATED',
              value: organization.createdAt != null
                  ? _formatDate(organization.createdAt!)
                  : 'N/A',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationDetailsSheet extends StatefulWidget {
  const _OrganizationDetailsSheet({
    required this.organization,
    required this.controller,
  });

  final OrganizationModel organization;
  final OrganizationsManagementController controller;

  @override
  State<_OrganizationDetailsSheet> createState() =>
      _OrganizationDetailsSheetState();
}

class _OrganizationDetailsSheetState extends State<_OrganizationDetailsSheet> {
  late Future<List<EmployeeModel>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  Future<List<EmployeeModel>> _loadEmployees() {
    return widget.controller.loadOrganizationEmployees(
      widget.organization.id ?? '',
    );
  }

  Future<void> _refreshEmployees() async {
    if (!mounted) return;
    setState(() {
      _employeesFuture = _loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final organization = widget.organization;
    final controller = widget.controller;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.pw24,
          AppSizes.ph20,
          AppSizes.pw24,
          AppSizes.ph20,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      organization.name,
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.h10),
              _InfoText(label: 'ADMIN EMAIL', value: organization.adminEmail),
              SizedBox(height: AppSizes.h6),
              _InfoText(label: 'CITY', value: organization.city),
              SizedBox(height: AppSizes.h6),
              _InfoText(
                label: 'ADDRESS',
                value: organization.address.isNotEmpty
                    ? organization.address
                    : 'N/A',
              ),
              SizedBox(height: AppSizes.h6),
              _InfoText(
                label: 'INDUSTRY',
                value: organization.industry.isNotEmpty
                    ? organization.industry
                    : 'N/A',
              ),
              SizedBox(height: AppSizes.h6),
              _InfoText(
                label: 'EMPLOYEE RANGE',
                value: organization.employeeRange.isNotEmpty
                    ? organization.employeeRange
                    : 'N/A',
              ),
              SizedBox(height: AppSizes.h6),
              _InfoText(
                label: 'STATUS',
                value: organization.status.toUpperCase(),
              ),
              SizedBox(height: AppSizes.ph12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isProcessingOrganization
                          ? null
                          : () => _showEditOrganizationDialog(
                              context,
                              organization,
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('EDIT'),
                    ),
                  ),
                  SizedBox(width: AppSizes.w12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.isProcessingOrganization
                          ? null
                          : () => _confirmDeleteOrganization(
                              context,
                              organization,
                            ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('DELETE'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.ph16),
              Text(
                'Employees',
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontSize: AppSizes.sp16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSizes.h10),
              Expanded(
                child: FutureBuilder<List<EmployeeModel>>(
                  future: _employeesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryColor,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load employees',
                          style: GoogleFonts.manrope(color: AppColors.error),
                        ),
                      );
                    }

                    final employees = snapshot.data ?? <EmployeeModel>[];
                    if (employees.isEmpty) {
                      return Center(
                        child: Text(
                          'No employees in this organization.',
                          style: GoogleFonts.manrope(
                            color: AppColors.textSubtitle,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: employees.length,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: AppSizes.h8),
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        return ListTile(
                          onTap: () => _showEmployeeDetails(context, employee),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                            side: const BorderSide(
                              color: AppColors.inputBorder,
                            ),
                          ),
                          tileColor: AppColors.sectionBackground,
                          title: Text(
                            employee.name,
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            employee.email,
                            style: GoogleFonts.manrope(
                              color: AppColors.textMuted,
                              fontSize: AppSizes.sp12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditOrganizationDialog(
    BuildContext context,
    OrganizationModel organization,
  ) async {
    final updated =
        await showDialog<bool>(
          context: context,
          builder: (context) => _EditOrganizationDialog(
            organization: organization,
            controller: widget.controller,
          ),
        ) ??
        false;

    if (updated && mounted) {
      Navigator.of(this.context).pop();
    }
  }

  Future<void> _confirmDeleteOrganization(
    BuildContext context,
    OrganizationModel organization,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                'Delete organization?',
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                'This will deactivate the organization and related users. Are you sure?',
                style: GoogleFonts.manrope(color: AppColors.textSubtitle),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'DELETE',
                    style: GoogleFonts.manrope(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    final success = await widget.controller.deleteOrganization(organization);

    if (success && navigator.mounted) {
      navigator.pop();
    }
  }

  Future<void> _showEmployeeDetails(
    BuildContext context,
    EmployeeModel employee,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EmployeeDetailsDialog(
        employee: employee,
        controller: widget.controller,
        onUpdated: _refreshEmployees,
      ),
    );
  }
}

class _EmployeeDetailsDialog extends StatefulWidget {
  const _EmployeeDetailsDialog({
    required this.employee,
    required this.controller,
    required this.onUpdated,
  });

  final EmployeeModel employee;
  final OrganizationsManagementController controller;
  final Future<void> Function() onUpdated;

  @override
  State<_EmployeeDetailsDialog> createState() => _EmployeeDetailsDialogState();
}

class _EmployeeDetailsDialogState extends State<_EmployeeDetailsDialog> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        employee.name,
        style: GoogleFonts.manrope(
          color: AppColors.textTitle,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoText(label: 'EMAIL', value: employee.email),
          SizedBox(height: AppSizes.h6),
          _InfoText(label: 'NATIONAL ID', value: employee.nationalId),
          SizedBox(height: AppSizes.h6),
          _InfoText(label: 'DEPARTMENT', value: employee.department),
          SizedBox(height: AppSizes.h6),
          _InfoText(label: 'STATUS', value: employee.status.toUpperCase()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: Text(
            'CLOSE',
            style: GoogleFonts.manrope(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _isBusy ? null : _showEditEmployeeDialog,
          child: Text(
            'EDIT',
            style: GoogleFonts.manrope(color: AppColors.primaryColor),
          ),
        ),
        TextButton(
          onPressed: _isBusy ? null : _confirmDeleteEmployee,
          child: Text(
            _isBusy ? 'PLEASE WAIT' : 'DELETE',
            style: GoogleFonts.manrope(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditEmployeeDialog() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    final employeeId = widget.employee.id ?? '';
    final latestEmployee = await widget.controller.loadEmployeeDetails(
      employeeId,
      fallback: widget.employee,
    );

    if (!mounted) return;

    setState(() {
      _isBusy = false;
    });

    if (latestEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load employee details.')),
      );
      return;
    }

    final updated =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _EditEmployeeDialog(
            employee: latestEmployee,
            controller: widget.controller,
          ),
        ) ??
        false;

    if (updated && mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      await widget.onUpdated();
      if (navigator.mounted) {
        navigator.pop();
      }
    }
  }

  Future<void> _confirmDeleteEmployee() async {
    if (_isBusy) return;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                'Delete employee?',
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                'This will deactivate the employee account and remove it from active lists.',
                style: GoogleFonts.manrope(color: AppColors.textSubtitle),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(color: AppColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'DELETE',
                    style: GoogleFonts.manrope(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() {
      _isBusy = true;
    });

    final latestEmployee = await widget.controller.loadEmployeeDetails(
      widget.employee.id ?? '',
      fallback: widget.employee,
    );

    if (!mounted) return;

    final success = await widget.controller.deleteEmployee(
      latestEmployee ?? widget.employee,
    );

    setState(() {
      _isBusy = false;
    });

    if (success && mounted) {
      await widget.onUpdated();
      if (navigator.mounted) {
        navigator.pop();
      }
    }
  }
}

class _EditOrganizationDialog extends StatefulWidget {
  const _EditOrganizationDialog({
    required this.organization,
    required this.controller,
  });

  final OrganizationModel organization;
  final OrganizationsManagementController controller;

  @override
  State<_EditOrganizationDialog> createState() =>
      _EditOrganizationDialogState();
}

class _EditOrganizationDialogState extends State<_EditOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _industryController;
  late final TextEditingController _employeeRangeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization.name);
    _cityController = TextEditingController(text: widget.organization.city);
    _addressController = TextEditingController(
      text: widget.organization.address,
    );
    _industryController = TextEditingController(
      text: widget.organization.industry,
    );
    _employeeRangeController = TextEditingController(
      text: widget.organization.employeeRange,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _industryController.dispose();
    _employeeRangeController.dispose();
    super.dispose();
  }

  Future<void> _closeSafely({Object? result}) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.mounted) {
      navigator.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        'Edit Organization',
        style: GoogleFonts.manrope(
          color: AppColors.textTitle,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: _nameController,
                  label: 'Organization name',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: AppSizes.h10),
                _DialogField(
                  controller: _cityController,
                  label: 'City',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: AppSizes.h10),
                _DialogField(controller: _addressController, label: 'Address'),
                SizedBox(height: AppSizes.h10),
                _DialogField(
                  controller: _industryController,
                  label: 'Industry',
                ),
                SizedBox(height: AppSizes.h10),
                _DialogField(
                  controller: _employeeRangeController,
                  label: 'Employee range',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () async => _closeSafely(result: false),
          child: Text(
            'CANCEL',
            style: GoogleFonts.manrope(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() {
                    _isSaving = true;
                  });

                  final success = await widget.controller.updateOrganization(
                    organizationId: widget.organization.id ?? '',
                    name: _nameController.text.trim(),
                    city: _cityController.text.trim(),
                    address: _addressController.text.trim(),
                    industry: _industryController.text.trim(),
                    employeeRange: _employeeRangeController.text.trim(),
                  );

                  await _closeSafely(result: success);
                },
          child: Text(
            _isSaving ? 'SAVING...' : 'SAVE',
            style: GoogleFonts.manrope(color: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _EditEmployeeDialog extends StatefulWidget {
  const _EditEmployeeDialog({required this.employee, required this.controller});

  final EmployeeModel employee;
  final OrganizationsManagementController controller;

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _nationalIdController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email);
    _nationalIdController = TextEditingController(
      text: widget.employee.nationalId,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _closeSafely({Object? result}) async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.mounted) {
      navigator.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        'Edit Employee',
        style: GoogleFonts.manrope(
          color: AppColors.textTitle,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: _nameController,
                  label: 'Full name',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: AppSizes.h10),
                _DialogField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                SizedBox(height: AppSizes.h10),
                _DialogField(
                  controller: _nationalIdController,
                  label: 'National ID',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () async => _closeSafely(result: false),
          child: Text(
            'CANCEL',
            style: GoogleFonts.manrope(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() {
                    _isSaving = true;
                  });

                  final success = await widget.controller.updateEmployee(
                    employeeId: widget.employee.id ?? '',
                    name: _nameController.text.trim(),
                    email: _emailController.text.trim(),
                    nationalId: _nationalIdController.text.trim(),
                  );

                  await _closeSafely(result: success);
                },
          child: Text(
            _isSaving ? 'SAVING...' : 'SAVE',
            style: GoogleFonts.manrope(color: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: GoogleFonts.manrope(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.manrope(fontSize: AppSizes.sp12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status.toLowerCase() == 'active';
    final color = isActive ? AppColors.primaryColor : AppColors.textMuted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw8,
        vertical: AppSizes.ph4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppSizes.r12),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.manrope(
          color: color,
          fontSize: AppSizes.sp10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_outlined,
            color: AppColors.textMuted,
            size: AppSizes.h40,
          ),
          SizedBox(height: AppSizes.ph12),
          Text(
            'No organizations found',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h6),
          Text(
            'Create your first organization to get started.',
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp12,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('CREATE ORGANIZATION'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: AppSizes.h40, color: AppColors.error),
          SizedBox(height: AppSizes.h8),
          Text(
            'Unable to load organizations',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
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
          SizedBox(height: AppSizes.ph16),
          OutlinedButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}
