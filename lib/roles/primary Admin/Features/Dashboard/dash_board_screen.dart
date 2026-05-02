import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import 'controllers/dashboard_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryColor,
          onRefresh: controller.loadStats,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.pw24,
                    AppSizes.ph20,
                    AppSizes.pw24,
                    AppSizes.ph8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dashboardTitle,
                        style: GoogleFonts.manrope(
                          color: AppColors.textTitle,
                          fontSize: AppSizes.sp24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: AppSizes.h4),
                      Text(
                        l.systemOverviewTitle,
                        style: GoogleFonts.manrope(
                          color: AppColors.textSubtitle,
                          fontSize: AppSizes.sp12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryColor),
                  ),
                )
              else if (controller.errorMessage != null)
                SliverFillRemaining(
                  child: _ErrorState(
                    message: controller.errorMessage!,
                    onRetry: controller.loadStats,
                  ),
                )
              else
                _buildContent(context, controller, l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardController controller,
    AppLocalizations l,
  ) {
    final stats = controller.stats!;

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw24,
        vertical: AppSizes.ph8,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── Stats Grid ───────────────────────────────────────────
          _SectionLabel(label: l.systemOverviewTitle),
          SizedBox(height: AppSizes.h12),
          _StatsGrid(stats: stats, l: l),
          SizedBox(height: AppSizes.ph20),

          // ── Weekly Activity Chart ────────────────────────────────
          _SectionLabel(label: l.weeklyActivityTitle),
          SizedBox(height: AppSizes.h12),
          _ChartCard(data: stats.weeklyActivity, l: l),
          SizedBox(height: AppSizes.ph20),
        ]),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.l});

  final DashboardStats stats;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.corporate_fare_outlined,
        l.totalOrganizationsLabel,
        '${stats.totalOrganizations}',
        const Color(0xFF818CF8),
      ),
      (
        Icons.admin_panel_settings_outlined,
        l.totalAdminsLabel,
        '${stats.totalAdmins}',
        const Color(0xFFFBBF24),
      ),
      (
        Icons.people_outline,
        l.totalEmployeesLabel,
        '${stats.totalEmployees}',
        AppColors.primaryColor,
      ),
      (
        Icons.bolt_outlined,
        l.activeUsersLabel,
        '${stats.activeUsers}',
        const Color(0xFF34D399),
      ),
      (
        Icons.bar_chart_outlined,
        l.recentActivityLabel,
        '${stats.recentActivity}',
        const Color(0xFFF472B6),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSizes.w12,
      mainAxisSpacing: AppSizes.h12,
      childAspectRatio: 1.25,
      children: items
          .map(
            (item) => _StatCard(
              icon: item.$1,
              label: item.$2,
              value: item.$3,
              color: item.$4,
            ),
          )
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.r8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontSize: AppSizes.sp20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Weekly Activity Chart ─────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data, required this.l});

  final List<DailyActivity> data;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.ph16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: data.every((d) => d.count == 0)
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.ph20),
                child: Text(
                  l.noActivityData,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp13,
                  ),
                ),
              ),
            )
          : _ActivityBarChart(data: data),
    );
  }
}

class _ActivityBarChart extends StatelessWidget {
  const _ActivityBarChart({required this.data});

  final List<DailyActivity> data;

  static const _maxBarHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    final maxCount = data.map((d) => d.count).reduce(max);

    return SizedBox(
      height: _maxBarHeight + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((day) {
          final barHeight = maxCount == 0
              ? 4.0
              : max(4.0, (day.count / maxCount) * _maxBarHeight);
          final isToday = _isToday(day.date);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.w2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (day.count > 0)
                    Text(
                      '${day.count}',
                      style: GoogleFonts.manrope(
                        color: isToday
                            ? AppColors.primaryColor
                            : AppColors.textMuted,
                        fontSize: AppSizes.sp9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(height: AppSizes.h4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primaryColor
                          : AppColors.primaryColor.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSizes.r4),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSizes.h8),
                  Text(
                    _dayLabel(day.date),
                    style: GoogleFonts.manrope(
                      color: isToday
                          ? AppColors.primaryColor
                          : AppColors.textMuted,
                      fontSize: AppSizes.sp9,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _dayLabel(DateTime date) {
    const labels = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
    return labels[date.weekday % 7];
  }
}

// ── Shared small widgets ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: GoogleFonts.manrope(
      color: AppColors.textMuted,
      fontSize: AppSizes.sp11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
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
              l.failedToLoadDashboard,
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
