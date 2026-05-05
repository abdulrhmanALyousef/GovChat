import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/activity_log_model.dart';
import '../../../../models/organization_model.dart';
import 'controllers/audit_controller.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuditController(),
      child: const _AuditView(),
    );
  }
}

class _AuditView extends StatefulWidget {
  const _AuditView();

  @override
  State<_AuditView> createState() => _AuditViewState();
}

class _AuditViewState extends State<_AuditView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ctrl = context.read<AuditController>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !ctrl.isLoading &&
        !ctrl.isLoadingMore &&
        ctrl.hasMore) {
      ctrl.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuditController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, controller, l),
            _buildSearchBar(context, controller, l),
            _buildActiveFilterChips(context, controller, l),
            Expanded(child: _buildBody(context, controller, l)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuditController controller,
    AppLocalizations l,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw24,
        AppSizes.ph20,
        AppSizes.pw16,
        AppSizes.ph8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.auditSystemLogsTitle,
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontSize: AppSizes.sp20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSizes.h4),
                Text(
                  l.viewUpdateManage,
                  style: GoogleFonts.manrope(
                    color: AppColors.textSubtitle,
                    fontSize: AppSizes.sp12,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: () => _showFilterSheet(context, controller, l),
              ),
              if (controller.activeFilterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${controller.activeFilterCount}',
                        style: GoogleFonts.manrope(
                          color: AppColors.buttonText,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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

  Widget _buildSearchBar(
    BuildContext context,
    AuditController controller,
    AppLocalizations l,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw24,
        vertical: AppSizes.ph4,
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontSize: AppSizes.sp13,
        ),
        onChanged: controller.updateSearch,
        decoration: InputDecoration(
          hintText: l.searchLogsHint,
          hintStyle: GoogleFonts.manrope(
            color: AppColors.hintText,
            fontSize: AppSizes.sp13,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.iconMuted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.iconMuted),
                  onPressed: () {
                    _searchController.clear();
                    controller.updateSearch('');
                  },
                )
              : null,
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw16,
            vertical: AppSizes.ph12,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(
    BuildContext context,
    AuditController controller,
    AppLocalizations l,
  ) {
    final chips = <Widget>[];

    if (controller.selectedOrgId != null) {
      final org = controller.organizations.firstWhere(
        (o) => o.id == controller.selectedOrgId,
        orElse: () => OrganizationModel(
          name: controller.selectedOrgId!,
          city: '',
          address: '',
          industry: '',
          employeeRange: '',
          adminEmail: '',
          adminUid: '',
          status: '',
        ),
      );
      chips.add(_FilterChip(
        label: org.name,
        onRemove: () => controller.applyFilters(
          orgId: null,
          role: controller.selectedRole,
          action: controller.selectedAction,
          from: controller.dateFrom,
          to: controller.dateTo,
        ),
      ));
    }

    if (controller.selectedRole != null) {
      chips.add(_FilterChip(
        label: _localizeRole(controller.selectedRole!, l),
        onRemove: () => controller.applyFilters(
          orgId: controller.selectedOrgId,
          role: null,
          action: controller.selectedAction,
          from: controller.dateFrom,
          to: controller.dateTo,
        ),
      ));
    }

    if (controller.selectedAction != null) {
      chips.add(_FilterChip(
        label: _localizeAction(controller.selectedAction!, l),
        onRemove: () => controller.applyFilters(
          orgId: controller.selectedOrgId,
          role: controller.selectedRole,
          action: null,
          from: controller.dateFrom,
          to: controller.dateTo,
        ),
      ));
    }

    if (controller.dateFrom != null) {
      chips.add(_FilterChip(
        label: '${l.dateFromLabel}: ${_formatDate(controller.dateFrom!)}',
        onRemove: () => controller.applyFilters(
          orgId: controller.selectedOrgId,
          role: controller.selectedRole,
          action: controller.selectedAction,
          from: null,
          to: controller.dateTo,
        ),
      ));
    }

    if (controller.dateTo != null) {
      chips.add(_FilterChip(
        label: '${l.dateToLabel}: ${_formatDate(controller.dateTo!)}',
        onRemove: () => controller.applyFilters(
          orgId: controller.selectedOrgId,
          role: controller.selectedRole,
          action: controller.selectedAction,
          from: controller.dateFrom,
          to: null,
        ),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: AppSizes.h40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        itemCount: chips.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSizes.w8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AuditController controller,
    AppLocalizations l,
  ) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(
        message: controller.errorMessage!,
        onRetry: controller.refresh,
      );
    }

    if (controller.logs.isEmpty) {
      return _EmptyState(onClear: controller.clearFilters, l: l);
    }

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSizes.pw24,
          AppSizes.ph8,
          AppSizes.pw24,
          AppSizes.ph20,
        ),
        itemCount: controller.logs.length + (controller.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: AppSizes.ph8),
        itemBuilder: (context, index) {
          if (index == controller.logs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primaryColor),
              ),
            );
          }
          return _LogCard(log: controller.logs[index], l: l);
        },
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    AuditController controller,
    AppLocalizations l,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
      ),
      builder: (_) => _FilterSheet(controller: controller),
    );
  }
}

// ── Log Card ──────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, required this.l});

  final ActivityLogModel log;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final actionLabel = _localizeAction(log.actionType, l);
    final roleColor   = _roleColor(log.performedByRole);

    return Container(
      padding: EdgeInsets.all(AppSizes.ph14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSizes.ph8),
                decoration: BoxDecoration(
                  color: _actionColor(log.actionType).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.r8),
                ),
                child: Icon(
                  _actionIcon(log.actionType),
                  color: _actionColor(log.actionType),
                  size: 16,
                ),
              ),
              SizedBox(width: AppSizes.w10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionLabel,
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontWeight: FontWeight.w700,
                        fontSize: AppSizes.sp13,
                      ),
                    ),
                    if (log.timestamp != null)
                      Text(
                        _formatDateTime(log.timestamp!),
                        style: GoogleFonts.manrope(
                          color: AppColors.textMuted,
                          fontSize: AppSizes.sp11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.pw8,
                  vertical: AppSizes.ph4,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.r8),
                  border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _localizeRole(log.performedByRole, l),
                  style: GoogleFonts.manrope(
                    color: roleColor,
                    fontSize: AppSizes.sp10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.h10),
          _InfoRow(
            label: l.actorLabel,
            value: log.performedByEmail.isNotEmpty
                ? log.performedByEmail
                : l.unknownUser,
          ),
          if (log.organizationName != null &&
              log.organizationName!.isNotEmpty) ...[
            SizedBox(height: AppSizes.h4),
            _InfoRow(label: l.organizationField, value: log.organizationName!),
          ],
          if (log.targetEmail != null && log.targetEmail!.isNotEmpty) ...[
            SizedBox(height: AppSizes.h4),
            _InfoRow(label: l.emailField, value: log.targetEmail!),
          ],
          SizedBox(height: AppSizes.h6),
          Text(
            _localizeDescription(log, l),
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: AppSizes.sp11,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter Bottom Sheet ───────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.controller});

  final AuditController controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _orgId;
  late String? _role;
  late String? _action;
  late DateTime? _from;
  late DateTime? _to;

  @override
  void initState() {
    super.initState();
    _orgId = widget.controller.selectedOrgId;
    _role = widget.controller.selectedRole;
    _action = widget.controller.selectedAction;
    _from = widget.controller.dateFrom;
    _to = widget.controller.dateTo;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final roleItems = [
      DropdownMenuItem<String?>(value: null, child: Text(l.allRolesFilter)),
      DropdownMenuItem<String?>(value: 'primary_admin', child: Text(l.rolePrimaryAdminLabel)),
      DropdownMenuItem<String?>(value: 'admin', child: Text(l.roleAdminLabel)),
      DropdownMenuItem<String?>(value: 'employee', child: Text(l.roleEmployeeLabel)),
    ];

    final actionItems = [
      DropdownMenuItem<String?>(value: null, child: Text(l.allActionsFilter)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionLogin, child: Text(l.logActionLogin)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionLogout, child: Text(l.logActionLogout)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionOrgCreated, child: Text(l.logActionOrgCreated)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionOrgUpdated, child: Text(l.logActionOrgUpdated)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionOrgDeleted, child: Text(l.logActionOrgDeleted)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionAdminCreated, child: Text(l.logActionAdminCreated)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionEmployeeApproved, child: Text(l.logActionEmployeeApproved)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionEmployeeRejected, child: Text(l.logActionEmployeeRejected)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionEmployeeUpdated, child: Text(l.logActionEmployeeUpdated)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionEmployeeDeleted, child: Text(l.logActionEmployeeDeleted)),
      DropdownMenuItem<String?>(value: ActivityLogService.actionPasswordChanged, child: Text(l.logActionPasswordChanged)),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.pw24,
          AppSizes.ph20,
          AppSizes.pw24,
          AppSizes.ph20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.filtersLabel,
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _orgId = null;
                      _role = null;
                      _action = null;
                      _from = null;
                      _to = null;
                    }),
                    child: Text(
                      l.clearFiltersButton,
                      style: GoogleFonts.manrope(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.ph16),

              _FilterLabel(label: l.organizationField),
              SizedBox(height: AppSizes.h8),
              _DropdownField<String?>(
                value: _orgId,
                hint: l.allOrganizationsFilter,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l.allOrganizationsFilter),
                  ),
                  ...widget.controller.organizations.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(o.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _orgId = v),
              ),
              SizedBox(height: AppSizes.ph12),

              _FilterLabel(label: l.roleAdminLabel),
              SizedBox(height: AppSizes.h8),
              _DropdownField<String?>(
                value: _role,
                hint: l.allRolesFilter,
                items: roleItems,
                onChanged: (v) => setState(() => _role = v),
              ),
              SizedBox(height: AppSizes.ph12),

              _FilterLabel(label: l.filtersLabel),
              SizedBox(height: AppSizes.h8),
              _DropdownField<String?>(
                value: _action,
                hint: l.allActionsFilter,
                items: actionItems,
                onChanged: (v) => setState(() => _action = v),
              ),
              SizedBox(height: AppSizes.ph12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilterLabel(label: l.dateFromLabel),
                        SizedBox(height: AppSizes.h8),
                        _DatePickerButton(
                          date: _from,
                          hint: l.dateNotSet,
                          onPick: () => _pickDate(context, isFrom: true),
                          onClear: _from != null ? () => setState(() => _from = null) : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSizes.w12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FilterLabel(label: l.dateToLabel),
                        SizedBox(height: AppSizes.h8),
                        _DatePickerButton(
                          date: _to,
                          hint: l.dateNotSet,
                          onPick: () => _pickDate(context, isFrom: false),
                          onClear: _to != null ? () => setState(() => _to = null) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.ph20),

              SizedBox(
                width: double.infinity,
                height: AppSizes.h48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      widget.controller.applyFilters(
                        orgId: _orgId,
                        role: _role,
                        action: _action,
                        from: _from,
                        to: _to,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r12),
                      ),
                    ),
                    child: Text(
                      l.applyFiltersButton,
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
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_from ?? now) : (_to ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2024),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryColor,
            onPrimary: AppColors.buttonText,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }
}

// ── Small reusable widgets ────────────────────────────────────────────

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: GoogleFonts.manrope(
      color: AppColors.textMuted,
      fontSize: AppSizes.sp11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.manrope(
              color: AppColors.hintText,
              fontSize: AppSizes.sp13,
            ),
          ),
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.cardBackground,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontSize: AppSizes.sp13,
          ),
          icon: const Icon(Icons.expand_more, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.date,
    required this.hint,
    required this.onPick,
    this.onClear,
  });

  final DateTime? date;
  final String hint;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw12,
          vertical: AppSizes.ph12,
        ),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppSizes.r12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? _formatDate(date!) : hint,
                style: GoogleFonts.manrope(
                  color: date != null ? AppColors.textPrimary : AppColors.hintText,
                  fontSize: AppSizes.sp12,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, color: AppColors.iconMuted, size: 16),
              )
            else
              const Icon(Icons.calendar_today_outlined, color: AppColors.iconMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw8,
        vertical: AppSizes.ph4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.r20),
        border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.primaryColor,
              fontSize: AppSizes.sp11,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: AppSizes.w6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppColors.primaryColor, size: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear, required this.l});

  final VoidCallback onClear;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, color: AppColors.textMuted, size: AppSizes.h40),
          SizedBox(height: AppSizes.ph12),
          Text(
            l.noLogsFound,
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h6),
          Text(
            l.noLogsFoundSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp12,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          OutlinedButton(onPressed: onClear, child: Text(l.clearFiltersButton)),
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
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.pw24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: AppSizes.h40, color: AppColors.error),
            SizedBox(height: AppSizes.h8),
            Text(
              l.somethingWentWrong,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSizes.h6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSubtitle,
                fontSize: AppSizes.sp12,
              ),
            ),
            SizedBox(height: AppSizes.ph16),
            OutlinedButton(onPressed: onRetry, child: Text(l.retryButton)),
          ],
        ),
      ),
    );
  }
}

// ── Pure helper functions ─────────────────────────────────────────────

String _localizeDescription(ActivityLogModel log, AppLocalizations l) {
  final key = log.descriptionKey.isNotEmpty ? log.descriptionKey : log.actionType;
  switch (key) {
    case ActivityLogService.actionLogin:
      return l.logDescLogin;
    case ActivityLogService.actionLogout:
      return l.logDescLogout;
    case ActivityLogService.actionOrgCreated:
      return l.logDescOrgCreated;
    case ActivityLogService.actionOrgUpdated:
      return l.logDescOrgUpdated;
    case ActivityLogService.actionOrgDeleted:
      return l.logDescOrgDeleted;
    case ActivityLogService.actionAdminCreated:
      return l.logDescAdminCreated;
    case ActivityLogService.actionEmployeeApproved:
      return l.logDescEmployeeApproved;
    case ActivityLogService.actionEmployeeRejected:
      return l.logDescEmployeeRejected;
    case ActivityLogService.actionEmployeeUpdated:
      return l.logDescEmployeeUpdated;
    case ActivityLogService.actionEmployeeDeleted:
      return l.logDescEmployeeDeleted;
    case ActivityLogService.actionPasswordChanged:
      return l.logDescPasswordChanged;
    case ActivityLogService.actionRequestSubmitted:
      return l.logDescRequestSubmitted;
    default:
      return key.isNotEmpty ? key : l.unknownUser;
  }
}

String _localizeAction(String action, AppLocalizations l) {
  switch (action) {
    case ActivityLogService.actionLogin:
      return l.logActionLogin;
    case ActivityLogService.actionLogout:
      return l.logActionLogout;
    case ActivityLogService.actionOrgCreated:
      return l.logActionOrgCreated;
    case ActivityLogService.actionOrgUpdated:
      return l.logActionOrgUpdated;
    case ActivityLogService.actionOrgDeleted:
      return l.logActionOrgDeleted;
    case ActivityLogService.actionAdminCreated:
      return l.logActionAdminCreated;
    case ActivityLogService.actionEmployeeApproved:
      return l.logActionEmployeeApproved;
    case ActivityLogService.actionEmployeeRejected:
      return l.logActionEmployeeRejected;
    case ActivityLogService.actionEmployeeUpdated:
      return l.logActionEmployeeUpdated;
    case ActivityLogService.actionEmployeeDeleted:
      return l.logActionEmployeeDeleted;
    case ActivityLogService.actionPasswordChanged:
      return l.logActionPasswordChanged;
    case ActivityLogService.actionRequestSubmitted:
      return l.logActionRequestSubmitted;
    default:
      return action;
  }
}

String _localizeRole(String role, AppLocalizations l) {
  switch (role) {
    case 'primary_admin':
      return l.rolePrimaryAdminLabel;
    case 'admin':
      return l.roleAdminLabel;
    case 'employee':
      return l.roleEmployeeLabel;
    default:
      return role;
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'primary_admin':
      return const Color(0xFF818CF8);
    case 'admin':
      return const Color(0xFFFBBF24);
    default:
      return AppColors.primaryColor;
  }
}

Color _actionColor(String action) {
  if (action.contains('deleted') || action.contains('rejected')) {
    return AppColors.error;
  }
  if (action.contains('created') || action.contains('approved')) {
    return AppColors.primaryColor;
  }
  if (action == ActivityLogService.actionLogin) {
    return const Color(0xFF60A5FA);
  }
  return AppColors.textMuted;
}

IconData _actionIcon(String action) {
  switch (action) {
    case ActivityLogService.actionLogin:
      return Icons.login_rounded;
    case ActivityLogService.actionLogout:
      return Icons.logout_rounded;
    case ActivityLogService.actionOrgCreated:
    case ActivityLogService.actionOrgUpdated:
    case ActivityLogService.actionOrgDeleted:
      return Icons.corporate_fare;
    case ActivityLogService.actionAdminCreated:
      return Icons.admin_panel_settings_outlined;
    case ActivityLogService.actionEmployeeApproved:
      return Icons.check_circle_outline;
    case ActivityLogService.actionEmployeeRejected:
      return Icons.cancel_outlined;
    case ActivityLogService.actionEmployeeUpdated:
      return Icons.person_outlined;
    case ActivityLogService.actionEmployeeDeleted:
      return Icons.person_remove_outlined;
    case ActivityLogService.actionPasswordChanged:
      return Icons.lock_outline;
    default:
      return Icons.history;
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

String _formatDateTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${_formatDate(dt)}  $h:$m';
}
