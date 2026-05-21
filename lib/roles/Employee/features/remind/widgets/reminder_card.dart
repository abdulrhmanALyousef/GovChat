import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_size.dart';
import '../../../../../core/theme/app_color.dart';
import '../../../../../models/reminder_model.dart';

const _kOverdueColor = Color(0xFFEF4444);
const _kCompleteColor = Color(0xFF4ADE80);
const _kMediumColor = Color(0xFFF59E0B);

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

  // Stripe / accent color: overdue always red, completed always muted
  Color _accentColor(BuildContext context) {
    if (reminder.isOverdue) return _kOverdueColor;
    if (reminder.isCompleted) return context.colors.textMuted;
    switch (reminder.priority) {
      case ReminderPriority.high:
        return _kOverdueColor;
      case ReminderPriority.medium:
        return _kMediumColor;
      case ReminderPriority.low:
        return _kCompleteColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context).index == 0;
    final dateStr = DateFormat('d MMM yyyy · HH:mm').format(reminder.dueDate);
    final isOverdue = reminder.isOverdue;
    final isCompleted = reminder.isCompleted;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppSizes.pw20),
        decoration: BoxDecoration(
          color: _kOverdueColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.r12),
        ),
        child: Icon(Icons.delete_outline,
            color: _kOverdueColor, size: AppSizes.sp22),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(vertical: AppSizes.h4),
          decoration: BoxDecoration(
            // Overdue: subtle red tint on background
            color: isOverdue
                ? _kOverdueColor.withValues(alpha: 0.06)
                : context.colors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r12),
            border: Border.all(
              color: isOverdue
                  ? _kOverdueColor.withValues(alpha: 0.5)
                  : context.colors.inputBorder,
              width: isOverdue ? 1.5 : 1.0,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority / status stripe
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: AppSizes.w4,
                  decoration: BoxDecoration(
                    color: _accentColor(context),
                    borderRadius: BorderRadius.only(
                      topLeft:
                          Radius.circular(isRtl ? 0 : AppSizes.r12),
                      bottomLeft:
                          Radius.circular(isRtl ? 0 : AppSizes.r12),
                      topRight:
                          Radius.circular(isRtl ? AppSizes.r12 : 0),
                      bottomRight:
                          Radius.circular(isRtl ? AppSizes.r12 : 0),
                    ),
                  ),
                ),
                // Checkbox
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSizes.pw12),
                  child: GestureDetector(
                    onTap: onToggleComplete,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: AppSizes.w22,
                      height: AppSizes.w22,
                      margin: EdgeInsets.only(top: AppSizes.h16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? _kCompleteColor
                            : isOverdue
                                ? _kOverdueColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? _kCompleteColor
                              : isOverdue
                                  ? _kOverdueColor
                                  : context.colors.inputBorder,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
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
                        // Title row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: isCompleted
                                      ? context.colors.textMuted
                                      : isOverdue
                                          ? _kOverdueColor
                                          : context.colors.textTitle,
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppSizes.sp14,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: context.colors.textMuted,
                                ),
                              ),
                            ),
                            SizedBox(width: AppSizes.pw8),
                            if (isOverdue) _OverdueBadge(),
                            if (isCompleted) _CompletedBadge(),
                          ],
                        ),
                        if (reminder.description.isNotEmpty) ...[
                          SizedBox(height: AppSizes.h4),
                          Text(
                            reminder.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: context.colors.textMuted,
                              fontSize: AppSizes.sp12,
                            ),
                          ),
                        ],
                        SizedBox(height: AppSizes.h8),
                        // Date row
                        Row(
                          children: [
                            Icon(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.schedule,
                              size: AppSizes.sp13,
                              color: isOverdue
                                  ? _kOverdueColor
                                  : context.colors.textMuted,
                            ),
                            SizedBox(width: AppSizes.pw4),
                            Text(
                              dateStr,
                              style: GoogleFonts.manrope(
                                color: isOverdue
                                    ? _kOverdueColor
                                    : context.colors.textMuted,
                                fontSize: AppSizes.sp11,
                                fontWeight: isOverdue
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (reminder.repeatType !=
                                ReminderRepeatType.none) ...[
                              SizedBox(width: AppSizes.pw8),
                              Icon(Icons.repeat,
                                  size: AppSizes.sp12,
                                  color: context.colors.textMuted),
                            ],
                            if (reminder.notificationEnabled) ...[
                              SizedBox(width: AppSizes.pw8),
                              Icon(Icons.notifications_outlined,
                                  size: AppSizes.sp12,
                                  color: context.colors.textMuted),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron
                Padding(
                  padding: EdgeInsets.only(right: AppSizes.pw12),
                  child: Icon(
                    Icons.chevron_right,
                    color: context.colors.iconMuted,
                    size: AppSizes.sp20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status badges ────────────────────────────────────────────────────────────

class _OverdueBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.localeOf(context).languageCode;
    final label = l10n == 'ar' ? 'متأخر' : 'OVERDUE';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw6, vertical: AppSizes.ph2),
      decoration: BoxDecoration(
        color: _kOverdueColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.r4),
        border: Border.all(color: _kOverdueColor.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: _kOverdueColor,
          fontSize: AppSizes.sp10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.localeOf(context).languageCode;
    final label = l10n == 'ar' ? 'مكتمل' : 'DONE';
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw6, vertical: AppSizes.ph2),
      decoration: BoxDecoration(
        color: _kCompleteColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.r4),
        border:
            Border.all(color: _kCompleteColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: _kCompleteColor,
          fontSize: AppSizes.sp10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
