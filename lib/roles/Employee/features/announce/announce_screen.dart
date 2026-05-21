import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/announcement_model.dart';
import '../../../../models/employee_model.dart';
import 'controller/announce_controller.dart';
import 'package:projects/l10n/app_localizations.dart';

class AnnounceScreen extends StatelessWidget {
  const AnnounceScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AnnounceController(employee),
      child: _AnnounceView(employee: employee),
    );
  }
}

class _AnnounceView extends StatelessWidget {
  const _AnnounceView({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ctrl = context.watch<AnnounceController>();

    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.colors.cardBackground,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: AppSizes.pw16),
          child: const Icon(Icons.shield_outlined, color: AppColors.primaryColor),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              style: GoogleFonts.manrope(
                color: context.colors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp16,
              ),
            ),
            Text(
              l.announcementsLabel,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(context, l, ctrl),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l,
    AnnounceController ctrl,
  ) {
    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (ctrl.errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.ph24),
          child: Text(
            l.somethingWentWrong,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (ctrl.announcements.isEmpty) {
      return _EmptyState(l: l);
    }

    return RefreshIndicator(
      color: AppColors.primaryColor,
      backgroundColor: context.colors.cardBackground,
      onRefresh: () async {},
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw16,
          vertical: AppSizes.ph16,
        ),
        itemCount: ctrl.announcements.length,
        separatorBuilder: (context, index) => SizedBox(height: AppSizes.h12),
        itemBuilder: (context, i) =>
            _AnnouncementCard(announcement: ctrl.announcements[i], l: l),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph24),
            decoration: BoxDecoration(
              color: context.colors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.inputBorder),
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: AppColors.primaryColor,
              size: AppSizes.sp40,
            ),
          ),
          SizedBox(height: AppSizes.h24),
          Text(
            l.announcementsLabel,
            style: GoogleFonts.manrope(
              color: context.colors.textTitle,
              fontWeight: FontWeight.w800,
              fontSize: AppSizes.sp20,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            l.noAnnouncementsDesc,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.l,
  });

  final AnnouncementModel announcement;
  final AppLocalizations l;

  Color get _priorityColor {
    switch (announcement.priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r8),
        border: Border.all(color: context.colors.inputBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.r8),
                  bottomLeft: Radius.circular(AppSizes.r8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.ph16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: GoogleFonts.manrope(
                              color: context.colors.textTitle,
                              fontWeight: FontWeight.w700,
                              fontSize: AppSizes.sp14,
                            ),
                          ),
                        ),
                        if (announcement.priority != 'normal')
                          _PriorityBadge(
                            priority: announcement.priority,
                            color: priorityColor,
                            l: l,
                          ),
                      ],
                    ),
                    SizedBox(height: AppSizes.h8),
                    Text(
                      announcement.content,
                      style: GoogleFonts.manrope(
                        color: context.colors.textSecondary,
                        fontSize: AppSizes.sp13,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: AppSizes.h12),
                    _DateRow(announcement: announcement, l: l),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({
    required this.priority,
    required this.color,
    required this.l,
  });

  final String priority;
  final Color color;
  final AppLocalizations l;

  String get label {
    if (priority == 'urgent') return l.announcementPriorityUrgent;
    if (priority == 'high') return l.announcementPriorityHigh;
    return l.announcementPriorityNormal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw8,
        vertical: AppSizes.ph4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.r4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: AppSizes.sp10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.announcement, required this.l});

  final AnnouncementModel announcement;
  final AppLocalizations l;

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.pw12,
      runSpacing: AppSizes.ph4,
      children: [
        if (announcement.createdAt != null)
          _MetaChip(
            icon: Icons.access_time_rounded,
            label: '${l.announcementPostedLabel}: ${_formatDate(announcement.createdAt!)}',
          ),
        if (announcement.expiresAt != null)
          _MetaChip(
            icon: Icons.event_outlined,
            label: '${l.announcementExpiresLabel}: ${_formatDate(announcement.expiresAt!)}',
            highlight: announcement.expiresAt!.difference(DateTime.now()).inHours < 24,
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFF59E0B) : context.colors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.sp12, color: color),
        SizedBox(width: AppSizes.pw6),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: color,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
