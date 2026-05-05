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
const _kGroupsColor = Color(0xFF818CF8);
const _kSecurityColor = Color(0xFFF87171);

Color _categoryColor(String category) {
  switch (category) {
    case 'authentication':
      return _kAuthColor;
    case 'employee':
      return _kEmployeeColor;
    case 'chat':
      return _kChatColor;
    case 'groups':
      return _kGroupsColor;
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
    case 'groups':
      return Icons.group_outlined;
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
    case 'logProjectGroupCreated':
      return l.logProjectGroupCreated;
    case 'logGroupMessageSent':
      return l.logGroupMessageSent;
    case 'logProjectGroupDeleted':
      return l.logProjectGroupDeleted;
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
// Main view — tabbed layout
// ═════════════════════════════════════════════════════════════════════════════

class _LogsView extends StatefulWidget {
  const _LogsView();

  @override
  State<_LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<_LogsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_tabCtrl.index == 0 &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250) {
      context.read<LogsController>().loadMore();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l.logsTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primaryColor,
          indicatorWeight: 2,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.navUnselected,
          labelStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            fontSize: AppSizes.sp12,
          ),
          tabs: [
            Tab(text: l.activityLogsTab),
            Tab(text: l.deletedMessagesTitle),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ActivityLogsTab(
            searchController: _searchController,
            scrollController: _scrollController,
          ),
          const _DeletedMessagesTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Activity logs tab — search + filters + paginated list
// ═════════════════════════════════════════════════════════════════════════════

class _ActivityLogsTab extends StatelessWidget {
  final TextEditingController searchController;
  final ScrollController scrollController;

  const _ActivityLogsTab({
    required this.searchController,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchBar(controller: searchController),
        const _CategoryFilterRow(),
        const _DateFilterRow(),
        const SizedBox(height: 4),
        Expanded(child: _LogsList(scrollController: scrollController)),
      ],
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
        separatorBuilder: (_, __) => SizedBox(width: AppSizes.w8),
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
          separatorBuilder: (_, __) => SizedBox(width: AppSizes.w8),
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
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.cardBackground,
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
      return _ErrorState(message: ctrl.errorMessage!, onRetry: ctrl.refresh);
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

// ─── Empty state ──────────────────────────────────────────────────────────────

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

// ─── Error state ──────────────────────────────────────────────────────────────

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
// Log item (rich display with colored accent bar)
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

// ═════════════════════════════════════════════════════════════════════════════
// Deleted messages tab
// ═════════════════════════════════════════════════════════════════════════════

class _DeletedMessagesTab extends StatelessWidget {
  const _DeletedMessagesTab();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LogsController>();
    final l = AppLocalizations.of(context)!;

    if (controller.isLoadingDeleted) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.deletedError != null) {
      return Center(
        child: Text(
          controller.deletedError!,
          style: GoogleFonts.manrope(
            color: AppColors.error,
            fontSize: AppSizes.sp14,
          ),
        ),
      );
    }

    if (controller.deletedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 56, color: AppColors.navUnselected),
            SizedBox(height: AppSizes.ph16),
            Text(
              l.noDeletedMessages,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w700,
                fontSize: AppSizes.sp16,
              ),
            ),
            SizedBox(height: AppSizes.h8),
            Text(
              l.noDeletedMessagesDesc,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppSizes.pw16),
      itemCount: controller.deletedMessages.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSizes.h8),
      itemBuilder: (_, i) =>
          _DeletedMessageCard(item: controller.deletedMessages[i], l: l),
    );
  }
}

// ─── Deleted message card ─────────────────────────────────────────────────────

class _DeletedMessageCard extends StatelessWidget {
  const _DeletedMessageCard({required this.item, required this.l});
  final DeletedMessageItem item;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.ph16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.error, size: AppSizes.sp16),
              SizedBox(width: AppSizes.w6),
              Text(
                l.deletedMessagesTitle,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.sp11,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (item.deletedAt != null)
                Text(
                  _formatDeletedTime(item.deletedAt!),
                  style: GoogleFonts.manrope(
                    color: AppColors.textSecondary,
                    fontSize: AppSizes.sp10,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSizes.h8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSizes.ph12),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.circular(AppSizes.r8),
            ),
            child: Text(
              item.text,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp13,
              ),
            ),
          ),
          SizedBox(height: AppSizes.h8),
          _InfoRow(label: l.senderLabel, value: item.senderId),
          SizedBox(height: AppSizes.h4),
          _InfoRow(label: l.deletedByLabel, value: item.deletedBy),
          SizedBox(height: AppSizes.h4),
          _InfoRow(
            label: l.locationLabel,
            value: item.departmentId.isNotEmpty ? item.departmentId : '—',
          ),
        ],
      ),
    );
  }

  String _formatDeletedTime(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: AppSizes.sp11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
