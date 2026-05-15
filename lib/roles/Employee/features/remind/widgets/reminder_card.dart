import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_size.dart';
import '../../../../../core/theme/app_color.dart';
import '../../../../../models/reminder_model.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDelete,
  });

  final ReminderModel reminder;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onDelete;

  Color get _priorityColor {
    switch (reminder.priority) {
      case ReminderPriority.high:
        return const Color(0xFFEF4444);
      case ReminderPriority.medium:
        return const Color(0xFFF59E0B);
      case ReminderPriority.low:
        return const Color(0xFF4ADE80);
    }
  }

  Color get _statusColor {
    if (reminder.isCompleted) return AppColors.textMuted;
    if (reminder.isOverdue) return const Color(0xFFEF4444);
    return AppColors.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context).index == 0;
    final dateStr = DateFormat('d MMM yyyy · HH:mm').format(reminder.dueDate);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppSizes.pw20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.r12),
        ),
        child: Icon(Icons.delete_outline,
            color: AppColors.error, size: AppSizes.sp22),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: AppSizes.h4),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority stripe
              Container(
                width: AppSizes.w4,
                decoration: BoxDecoration(
                  color: _priorityColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(
                        isRtl ? 0 : AppSizes.r12),
                    bottomLeft: Radius.circular(
                        isRtl ? 0 : AppSizes.r12),
                    topRight: Radius.circular(
                        isRtl ? AppSizes.r12 : 0),
                    bottomRight: Radius.circular(
                        isRtl ? AppSizes.r12 : 0),
                  ),
                ),
              ),
              // Checkbox
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes.pw12),
                child: GestureDetector(
                  onTap: onToggleComplete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: AppSizes.w22,
                    height: AppSizes.w22,
                    margin: EdgeInsets.only(top: AppSizes.h16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reminder.isCompleted
                          ? AppColors.primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: reminder.isCompleted
                            ? AppColors.primaryColor
                            : AppColors.inputBorder,
                        width: 2,
                      ),
                    ),
                    child: reminder.isCompleted
                        ? Icon(Icons.check,
                            size: AppSizes.sp12,
                            color: AppColors.buttonText)
                        : null,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSizes.h14,
                    horizontal: AppSizes.pw4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: reminder.isCompleted
                                    ? AppColors.textMuted
                                    : AppColors.textTitle,
                                fontWeight: FontWeight.w700,
                                fontSize: AppSizes.sp14,
                                decoration: reminder.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSizes.pw8),
                          _StatusBadge(color: _statusColor, reminder: reminder),
                        ],
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        SizedBox(height: AppSizes.h4),
                        Text(
                          reminder.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: AppSizes.sp12,
                          ),
                        ),
                      ],
                      SizedBox(height: AppSizes.h8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: AppSizes.sp12,
                              color: _statusColor),
                          SizedBox(width: AppSizes.pw4),
                          Text(
                            dateStr,
                            style: GoogleFonts.manrope(
                              color: _statusColor,
                              fontSize: AppSizes.sp11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (reminder.repeatType != ReminderRepeatType.none) ...[
                            SizedBox(width: AppSizes.pw8),
                            Icon(Icons.repeat,
                                size: AppSizes.sp12,
                                color: AppColors.textMuted),
                          ],
                          if (reminder.notificationEnabled) ...[
                            SizedBox(width: AppSizes.pw8),
                            Icon(Icons.notifications_outlined,
                                size: AppSizes.sp12,
                                color: AppColors.textMuted),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Edit icon
              Padding(
                padding: EdgeInsets.only(right: AppSizes.pw12),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.iconMuted,
                  size: AppSizes.sp20,
                ),
              ),
            ],
          ),
          ),   // IntrinsicHeight
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.color, required this.reminder});

  final Color color;
  final ReminderModel reminder;

  String _label(BuildContext context) {
    if (reminder.isCompleted) return '✓';
    if (reminder.isOverdue) return '!';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label(context);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw6, vertical: AppSizes.ph2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.r4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: AppSizes.sp10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
