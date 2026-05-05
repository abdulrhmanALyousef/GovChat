import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/activity_log_model.dart';
import 'controller/logs_controller.dart';

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

class _LogsView extends StatefulWidget {
  const _LogsView();

  @override
  State<_LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<_LogsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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
        children: const [
          _ActivityLogsTab(),
          _DeletedMessagesTab(),
        ],
      ),
    );
  }
}

// ─── Activity Logs Tab ───────────────────────────────────────────────────────

class _ActivityLogsTab extends StatelessWidget {
  const _ActivityLogsTab();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LogsController>();
    final l = AppLocalizations.of(context)!;

    if (controller.isLoadingLogs) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.logsError != null) {
      return Center(
        child: Text(
          controller.logsError!,
          style: GoogleFonts.manrope(
              color: AppColors.error, fontSize: AppSizes.sp14),
        ),
      );
    }

    if (controller.activityLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: AppColors.navUnselected),
            SizedBox(height: AppSizes.ph16),
            Text(
              l.noActivityLogs,
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(AppSizes.pw16),
      itemCount: controller.activityLogs.length,
      separatorBuilder: (context, index) => SizedBox(height: AppSizes.h8),
      itemBuilder: (_, i) => _LogCard(log: controller.activityLogs[i]),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final ActivityLogModel log;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.ph12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph8),
            decoration: BoxDecoration(
              color: _categoryColor(log.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.r8),
            ),
            child: Icon(
              _categoryIcon(log.category),
              color: _categoryColor(log.category),
              size: 16,
            ),
          ),
          SizedBox(width: AppSizes.w10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.actionType,
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.sp12,
                  ),
                ),
                SizedBox(height: AppSizes.h4),
                Text(
                  log.performedByEmail,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp11,
                  ),
                ),
              ],
            ),
          ),
          if (log.timestamp != null)
            Text(
              _formatTime(log.timestamp!),
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: AppSizes.sp10,
              ),
            ),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'authentication':
        return const Color(0xFF60A5FA);
      case 'chat':
        return const Color(0xFF34D399);
      case 'groups':
        return const Color(0xFFA78BFA);
      default:
        return AppColors.textMuted;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'authentication':
        return Icons.lock_outline;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'groups':
        return Icons.group_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Deleted Messages Tab ────────────────────────────────────────────────────

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
              color: AppColors.error, fontSize: AppSizes.sp14),
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
      separatorBuilder: (context, index) => SizedBox(height: AppSizes.h8),
      itemBuilder: (_, i) =>
          _DeletedMessageCard(item: controller.deletedMessages[i], l: l),
    );
  }
}

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
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: AppSizes.sp16,
              ),
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
                  _formatTime(item.deletedAt!),
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

  String _formatTime(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}

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
