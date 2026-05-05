import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/activity_log_model.dart';
import 'controller/logs_controller.dart';

// ── Colors & icons per category ───────────────────────────────────────────────
const _kAuthColor = Color(0xFF60A5FA);
const _kEmployeeColor = Color(0xFF34D399);
const _kChatColor = Color(0xFFA78BFA);
const _kSecurityColor = Color(0xFFF87171);

Color _categoryColor(String category) {
  switch (category) {
    case 'authentication':
      return _kAuthColor;
    case 'employee':
      return _kEmployeeColor;
    case 'chat':
      return _kChatColor;
    default:
      return _kSecurityColor;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'authentication':
      return Icons.lock_outline;
    case 'employee':
      return Icons.person_outline;
    case 'chat':
      return Icons.chat_bubble_outline;
    default:
      return Icons.shield_outlined;
  }
}

// ── Localize descriptionKey → UI text ─────────────────────────────────────────
String _localizeKey(String key, AppLocalizations l) {
  switch (key) {
    case 'logLoginSuccess':
      return l.logLoginSuccess;
    case 'logLoginFailure':
      return l.logLoginFailure;
    case 'logLogout':
      return l.logLogout;
    case 'logPasswordChanged':
      return l.logPasswordChanged;
    case 'logFirstLoginPasswordReset':
      return l.logFirstLoginPasswordReset;
    case 'logAccessRequestSubmitted':
      return l.logAccessRequestSubmitted;
    case 'logAccessRequestApproved':
      return l.logAccessRequestApproved;
    case 'logAccessRequestRejected':
      return l.logAccessRequestRejected;
    case 'logEmployeeUpdated':
      return l.logEmployeeUpdated;
    case 'logEmployeeDeleted':
      return l.logEmployeeDeleted;
    case 'logMessageSent':
      return l.logMessageSent;
    case 'logMessageDeleted':
      return l.logMessageDeleted;
    case 'logUnauthorizedAccess':
      return l.logUnauthorizedAccess;
    case 'logAutoLogoutInactivity':
      return l.logAutoLogoutInactivity;
    case 'logRoleMisuseAttempt':
      return l.logRoleMisuseAttempt;
    default:
      return l.logUnknownAction;
  }
}

// ── Relative timestamp ────────────────────────────────────────────────────────
String _formatTimestamp(DateTime? ts, AppLocalizations l) {
  if (ts == null) return l.awaitingTimestamp;
  final diff = DateTime.now().difference(ts);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.timeDaysAgo(diff.inDays);
  // Older: show date
  return '${ts.day}/${ts.month}/${ts.year}';
}

// ═════════════════════════════════════════════════════════════════════════════
// Entry point
// ═════════════════════════════════════════════════════════════════════════════

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LogsController(),
      child: const _LogsView(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Main view
// ═════════════════════════════════════════════════════════════════════════════

class _LogsView extends StatefulWidget {
  const _LogsView();

  @override
  State<_LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<_LogsView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      context.read<LogsController>().loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          l.logsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.sp16,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchController),
          _CategoryFilterRow(),
          _DateFilterRow(),
          const SizedBox(height: 4),
          Expanded(child: _LogsList(scrollController: _scrollController)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Search bar
// ═════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.read<LogsController>();
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw24,
        vertical: AppSizes.ph16 * 0.75,
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontSize: AppSizes.sp14,
        ),
        onChanged: ctrl.setSearch,
        decoration: InputDecoration(
          hintText: l.logSearchHint,
          hintStyle: GoogleFonts.manrope(
            color: AppColors.hintText,
            fontSize: AppSizes.sp13,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.iconMuted),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context2, value, child) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.iconMuted),
                    onPressed: () {
                      controller.clear();
                      ctrl.setSearch('');
                    },
                  ),
          ),
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw24,
            vertical: AppSizes.ph16 * 0.6,
          ),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Category filter chips
// ═════════════════════════════════════════════════════════════════════════════

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.watch<LogsController>();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final chips = [
      _ChipDef(label: l.logFilterAll, value: null, color: AppColors.primaryColor),
      _ChipDef(label: l.logFilterAuth, value: 'authentication', color: _kAuthColor),
      _ChipDef(label: l.logFilterEmployee, value: 'employee', color: _kEmployeeColor),
      _ChipDef(label: l.logFilterChat, value: 'chat', color: _kChatColor),
      _ChipDef(label: l.logFilterSecurity, value: 'security', color: _kSecurityColor),
    ];

    return SizedBox(
      height: AppSizes.h35,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        reverse: isRtl,
        itemCount: chips.length,
        separatorBuilder: (_, idx) => SizedBox(width: AppSizes.w8),
        itemBuilder: (_, i) {
          final chip = chips[i];
          final selected = ctrl.selectedCategory == chip.value;
          return _FilterChip(
            label: chip.label,
            selected: selected,
            activeColor: chip.color,
            onTap: () => ctrl.setCategory(chip.value),
          );
        },
      ),
    );
  }
}

class _ChipDef {
  final String label;
  final String? value;
  final Color color;
  const _ChipDef({required this.label, required this.value, required this.color});
}

// ═════════════════════════════════════════════════════════════════════════════
// Date filter chips
// ═════════════════════════════════════════════════════════════════════════════

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.watch<LogsController>();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final chips = [
      _DateChipDef(label: l.logDateAll, value: LogDateFilter.all),
      _DateChipDef(label: l.logDateToday, value: LogDateFilter.today),
      _DateChipDef(label: l.logDateLast7Days, value: LogDateFilter.last7Days),
    ];

    return Padding(
      padding: EdgeInsets.only(top: AppSizes.ph8, bottom: AppSizes.ph8),
      child: SizedBox(
        height: AppSizes.h32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
          reverse: isRtl,
          itemCount: chips.length,
          separatorBuilder: (_, idx) => SizedBox(width: AppSizes.w8),
          itemBuilder: (_, i) {
            final chip = chips[i];
            final selected = ctrl.dateFilter == chip.value;
            return _FilterChip(
              label: chip.label,
              selected: selected,
              activeColor: AppColors.textSecondary,
              onTap: () => ctrl.setDateFilter(chip.value),
            );
          },
        ),
      ),
    );
  }
}

class _DateChipDef {
  final String label;
  final LogDateFilter value;
  const _DateChipDef({required this.label, required this.value});
}

// ─── Generic chip widget ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw16,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.15) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r20),
          border: Border.all(
            color: selected ? activeColor : AppColors.inputBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: selected ? activeColor : AppColors.textSecondary,
            fontSize: AppSizes.sp12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Logs list
// ═════════════════════════════════════════════════════════════════════════════

class _LogsList extends StatelessWidget {
  final ScrollController scrollController;
  const _LogsList({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.watch<LogsController>();

    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (ctrl.errorMessage != null) {
      return _ErrorState(
        message: ctrl.errorMessage!,
        onRetry: ctrl.refresh,
      );
    }

    final logs = ctrl.displayedLogs;
    if (logs.isEmpty) {
      return _EmptyState(l: l);
    }

    return RefreshIndicator(
      color: AppColors.primaryColor,
      backgroundColor: AppColors.cardBackground,
      onRefresh: ctrl.refresh,
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw24,
          vertical: AppSizes.ph8,
        ),
        itemCount: logs.length + (ctrl.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == logs.length) {
            return _LoadMoreTile(ctrl: ctrl, l: l);
          }
          return _LogItem(log: logs[index]);
        },
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppLocalizations l;
  const _EmptyState({required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_outlined,
              size: AppSizes.h56,
              color: AppColors.iconMuted,
            ),
            SizedBox(height: AppSizes.h16),
            Text(
              l.logNoLogsYet,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.h8),
            Text(
              l.logActivityWillAppear,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: AppSizes.h48),
            SizedBox(height: AppSizes.h16),
            Text(
              message,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp13,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSizes.h16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l.retryButton,
                style: GoogleFonts.manrope(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Load more tile ───────────────────────────────────────────────────────────

class _LoadMoreTile extends StatelessWidget {
  final LogsController ctrl;
  final AppLocalizations l;
  const _LoadMoreTile({required this.ctrl, required this.l});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.ph16),
      child: ctrl.isLoadingMore
          ? const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primaryColor,
                  strokeWidth: 2,
                ),
              ),
            )
          : Center(
              child: TextButton(
                onPressed: ctrl.loadMore,
                child: Text(
                  l.logLoadMore,
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.sp13,
                  ),
                ),
              ),
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Log item
// ═════════════════════════════════════════════════════════════════════════════

class _LogItem extends StatelessWidget {
  final ActivityLogModel log;
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = _categoryColor(log.category);
    final icon = _categoryIcon(log.category);
    final title = _localizeKey(log.descriptionKey, l);
    final performer = log.performedByName?.isNotEmpty == true
        ? log.performedByName!
        : log.performedByUserId;
    final timeStr = _formatTimestamp(log.timestamp, l);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.ph8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r12),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left/right accent bar
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isRtl ? 0 : AppSizes.r12),
                    bottomLeft: Radius.circular(isRtl ? 0 : AppSizes.r12),
                    topRight: Radius.circular(isRtl ? AppSizes.r12 : 0),
                    bottomRight: Radius.circular(isRtl ? AppSizes.r12 : 0),
                  ),
                ),
              ),
              // Icon
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.pw16,
                  vertical: AppSizes.ph16,
                ),
                child: Container(
                  width: AppSizes.w42,
                  height: AppSizes.h40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: AppSizes.sp18),
                ),
              ),
              // Text content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.ph12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          color: AppColors.textPrimary,
                          fontSize: AppSizes.sp14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSizes.h4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: AppSizes.sp12,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: AppSizes.w6),
                          Flexible(
                            child: Text(
                              '${l.logPerformedBy} $performer',
                              style: GoogleFonts.manrope(
                                color: AppColors.textSecondary,
                                fontSize: AppSizes.sp12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Timestamp
              Padding(
                padding: EdgeInsets.only(
                  right: isRtl ? 0 : AppSizes.pw16,
                  left: isRtl ? AppSizes.pw16 : 0,
                  top: AppSizes.ph12,
                ),
                child: Text(
                  timeStr,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
