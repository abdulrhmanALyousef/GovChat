import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/reminder_model.dart';
import 'controller/reminder_controller.dart';
import 'reminder_form_screen.dart';
import 'widgets/reminder_card.dart';

class RemindScreen extends StatelessWidget {
  const RemindScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderController(employee: employee),
      child: _View(employee: employee),
    );
  }
}

class _View extends StatefulWidget {
  const _View({required this.employee});
  final EmployeeModel employee;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm(BuildContext context, {ReminderModel? existing}) {
    final ctrl = context.read<ReminderController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: ReminderFormScreen(
            employee: widget.employee,
            existing: existing,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ReminderModel reminder) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.read<ReminderController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.r16)),
        title: Text(
          l.deleteReminderTitle,
          style: GoogleFonts.manrope(
              color: AppColors.textTitle, fontWeight: FontWeight.w800),
        ),
        content: Text(
          l.deleteReminderConfirm,
          style: GoogleFonts.manrope(
              color: AppColors.textMuted, fontSize: AppSizes.sp14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancelButton,
                style: GoogleFonts.manrope(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ctrl.deleteReminder(reminder);
            },
            child: Text(l.deleteButton,
                style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.watch<ReminderController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: _buildAppBar(context, l, ctrl),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.buttonText,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_searchOpen) _SearchBar(ctrl: ctrl, searchCtrl: _searchCtrl),
          _FilterBar(ctrl: ctrl),
          Expanded(child: _Body(ctrl: ctrl, onEdit: (r) => _openForm(context, existing: r), onDelete: (r) => _confirmDelete(context, r))),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
      BuildContext context, AppLocalizations l, ReminderController ctrl) {
    return AppBar(
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      leading: Padding(
        padding: EdgeInsets.only(left: AppSizes.pw16),
        child: const Icon(Icons.shield_outlined,
            color: AppColors.primaryColor),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontWeight: FontWeight.w800,
              fontSize: AppSizes.sp16,
            ),
          ),
          Text(
            l.remindersLabel,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        if (ctrl.overdueCount > 0)
          Padding(
            padding: EdgeInsets.only(right: AppSizes.pw4),
            child: _OverdueBadge(count: ctrl.overdueCount),
          ),
        IconButton(
          icon: Icon(
            _searchOpen ? Icons.search_off : Icons.search,
            color: AppColors.textTitle,
          ),
          onPressed: () {
            setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _searchCtrl.clear();
                ctrl.setSearch('');
              }
            });
          },
        ),
        SizedBox(width: AppSizes.pw4),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl, required this.searchCtrl});
  final ReminderController ctrl;
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.cardBackground,
      padding: EdgeInsets.fromLTRB(
          AppSizes.pw16, 0, AppSizes.pw16, AppSizes.ph12),
      child: TextField(
        controller: searchCtrl,
        autofocus: true,
        style: GoogleFonts.manrope(
            color: AppColors.textTitle, fontSize: AppSizes.sp14),
        decoration: InputDecoration(
          hintText: l.searchRemindersHint,
          hintStyle: GoogleFonts.manrope(
              color: AppColors.hintText, fontSize: AppSizes.sp14),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.iconMuted),
          filled: true,
          fillColor: AppColors.sectionBackground,
          contentPadding:
              EdgeInsets.symmetric(vertical: AppSizes.ph10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.r10),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.r10),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.r10),
            borderSide: const BorderSide(
                color: AppColors.inputFocusBorder, width: 1.5),
          ),
        ),
        onChanged: ctrl.setSearch,
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.ctrl});
  final ReminderController ctrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final filters = [
      (ReminderFilter.all, l.filterAll),
      (ReminderFilter.active, l.filterActive),
      (ReminderFilter.overdue, l.filterOverdue),
      (ReminderFilter.completed, l.filterCompleted),
      (ReminderFilter.highPriority, l.filterHighPriority),
    ];

    return Container(
      color: AppColors.cardBackground,
      padding: EdgeInsets.only(bottom: AppSizes.ph10),
      height: AppSizes.h44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
        itemCount: filters.length,
        separatorBuilder: (context0, index0) => SizedBox(width: AppSizes.pw8),
        itemBuilder: (ctx, i) {
          final (filter, label) = filters[i];
          final selected = ctrl.filter == filter;
          return GestureDetector(
            onTap: () => ctrl.setFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: AppSizes.pw14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryColor.withValues(alpha: 0.15)
                    : AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(AppSizes.r20),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryColor
                      : AppColors.inputBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  color: selected
                      ? AppColors.primaryColor
                      : AppColors.textMuted,
                  fontSize: AppSizes.sp12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.ctrl,
      required this.onEdit,
      required this.onDelete});
  final ReminderController ctrl;
  final void Function(ReminderModel) onEdit;
  final void Function(ReminderModel) onDelete;

  @override
  Widget build(BuildContext context) {
    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (ctrl.error != null) {
      return _ErrorState(error: ctrl.error!);
    }

    final items = ctrl.filteredReminders;
    if (items.isEmpty) {
      return _EmptyState(
          hasSearch: ctrl.searchQuery.isNotEmpty,
          filter: ctrl.filter);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          AppSizes.pw16, AppSizes.ph12, AppSizes.pw16, AppSizes.h80),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final reminder = items[i];
        return ReminderCard(
          reminder: reminder,
          onTap: () => onEdit(reminder),
          onToggleComplete: () => ctrl.toggleComplete(reminder),
          onDelete: () => onDelete(reminder),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch, required this.filter});
  final bool hasSearch;
  final ReminderFilter filter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.notifications_none,
              color: AppColors.primaryColor,
              size: AppSizes.sp36,
            ),
          ),
          SizedBox(height: AppSizes.h20),
          Text(
            hasSearch ? l.noSearchResults : l.noRemindersYet,
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontWeight: FontWeight.w700,
              fontSize: AppSizes.sp16,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            hasSearch ? l.noSearchResultsDesc : l.noRemindersDesc,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        error,
        style: GoogleFonts.manrope(
            color: AppColors.error, fontSize: AppSizes.sp14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _OverdueBadge extends StatelessWidget {
  const _OverdueBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw8, vertical: AppSizes.ph2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.r10),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.manrope(
          color: AppColors.error,
          fontSize: AppSizes.sp11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
