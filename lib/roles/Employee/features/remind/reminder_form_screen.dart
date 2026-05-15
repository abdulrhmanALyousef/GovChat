import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/reminder_model.dart';
import 'controller/reminder_controller.dart';

class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({
    super.key,
    required this.employee,
    this.existing,
  });

  final EmployeeModel employee;
  final ReminderModel? existing;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  late ReminderPriority _priority;
  late DateTime _dueDate;
  late int _remindBeforeMinutes;
  late ReminderRepeatType _repeatType;
  late int _repeatInterval;
  late bool _notifEnabled;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priority = e?.priority ?? ReminderPriority.medium;
    _dueDate =
        e?.dueDate ?? DateTime.now().add(const Duration(hours: 1));
    _remindBeforeMinutes = e?.remindBeforeMinutes ?? 0;
    _repeatType = e?.repeatType ?? ReminderRepeatType.none;
    _repeatInterval = e?.repeatInterval ?? 1;
    _notifEnabled = e?.notificationEnabled ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => _darkPickerTheme(ctx, child),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(
          picked.year, picked.month, picked.day,
          _dueDate.hour, _dueDate.minute);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
      builder: (ctx, child) => _darkPickerTheme(ctx, child),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = DateTime(
          _dueDate.year, _dueDate.month, _dueDate.day,
          picked.hour, picked.minute);
    });
  }

  Widget _darkPickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryColor,
          onPrimary: AppColors.buttonText,
          surface: AppColors.cardBackground,
          onSurface: AppColors.textTitle,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ctrl = context.read<ReminderController>();
    final now = DateTime.now();

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        remindBeforeMinutes: _remindBeforeMinutes,
        repeatType: _repeatType,
        repeatInterval: _repeatInterval,
        notificationEnabled: _notifEnabled,
        updatedAt: now,
      );
      await ctrl.updateReminder(updated);
    } else {
      final reminder = ReminderModel(
        id: '',
        employeeId: widget.employee.id ?? '',
        organizationId: widget.employee.organizationId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        remindBeforeMinutes: _remindBeforeMinutes,
        repeatType: _repeatType,
        repeatInterval: _repeatInterval,
        notificationEnabled: _notifEnabled,
        createdAt: now,
        updatedAt: now,
      );
      await ctrl.createReminder(reminder);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context).index == 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isRtl ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
            color: AppColors.textTitle,
            size: AppSizes.sp18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? l.editReminderTitle : l.newReminderTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(AppSizes.ph20),
          children: [
            _Section(label: l.reminderDetailsSectionLabel, children: [
              _Field(
                controller: _titleCtrl,
                label: l.reminderTitleLabel,
                hint: l.reminderTitleHint,
                maxLength: 80,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.requiredField : null,
              ),
              SizedBox(height: AppSizes.h14),
              _Field(
                controller: _descCtrl,
                label: l.reminderDescLabel,
                hint: l.reminderDescHint,
                maxLines: 3,
              ),
            ]),
            SizedBox(height: AppSizes.h20),
            _Section(label: l.priorityLabel, children: [
              _PrioritySelector(
                value: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
            ]),
            SizedBox(height: AppSizes.h20),
            _Section(label: l.scheduleSectionLabel, children: [
              _DateTimeTile(
                icon: Icons.calendar_today_outlined,
                label: l.dueDateLabel,
                value: DateFormat('EEE, d MMM yyyy').format(_dueDate),
                onTap: _pickDate,
              ),
              SizedBox(height: AppSizes.h10),
              _DateTimeTile(
                icon: Icons.access_time,
                label: l.dueTimeLabel,
                value: DateFormat('HH:mm').format(_dueDate),
                onTap: _pickTime,
              ),
              SizedBox(height: AppSizes.h14),
              _RemindBeforeSelector(
                value: _remindBeforeMinutes,
                onChanged: (v) => setState(() => _remindBeforeMinutes = v),
              ),
            ]),
            SizedBox(height: AppSizes.h20),
            _Section(label: l.repeatSectionLabel, children: [
              _RepeatSelector(
                value: _repeatType,
                interval: _repeatInterval,
                onTypeChanged: (t) => setState(() => _repeatType = t),
                onIntervalChanged: (i) => setState(() => _repeatInterval = i),
              ),
            ]),
            SizedBox(height: AppSizes.h20),
            _Section(label: l.notificationSectionLabel, children: [
              _NotificationToggle(
                enabled: _notifEnabled,
                onChanged: (v) => setState(() => _notifEnabled = v),
              ),
            ]),
            SizedBox(height: AppSizes.h32),
            _SaveButton(saving: _saving, isEdit: _isEdit, onSave: _save),
            SizedBox(height: AppSizes.h20),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.primaryColor,
            fontSize: AppSizes.sp11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: AppSizes.h10),
        Container(
          padding: EdgeInsets.all(AppSizes.ph16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Text field ───────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp11,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: AppSizes.h6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.manrope(
              color: AppColors.textTitle, fontSize: AppSizes.sp14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
                color: AppColors.hintText, fontSize: AppSizes.sp14),
            filled: true,
            fillColor: AppColors.inputFill,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.r8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.r8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.r8),
              borderSide: const BorderSide(
                  color: AppColors.inputFocusBorder, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.r8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ── Priority selector ────────────────────────────────────────────────────────

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector(
      {required this.value, required this.onChanged});
  final ReminderPriority value;
  final ValueChanged<ReminderPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = [
      (ReminderPriority.low, l.priorityLow, const Color(0xFF4ADE80)),
      (ReminderPriority.medium, l.priorityMedium, const Color(0xFFF59E0B)),
      (ReminderPriority.high, l.priorityHigh, const Color(0xFFEF4444)),
    ];
    return Row(
      children: items.map((item) {
        final (priority, label, color) = item;
        final selected = value == priority;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(priority),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.symmetric(horizontal: AppSizes.pw4),
              padding: EdgeInsets.symmetric(vertical: AppSizes.ph10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(AppSizes.r8),
                border: Border.all(
                  color: selected ? color : AppColors.inputBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    selected ? Icons.flag : Icons.flag_outlined,
                    color: selected ? color : AppColors.textMuted,
                    size: AppSizes.sp18,
                  ),
                  SizedBox(height: AppSizes.h4),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: selected ? color : AppColors.textMuted,
                      fontSize: AppSizes.sp11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date/time tile ───────────────────────────────────────────────────────────

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw12, vertical: AppSizes.ph12),
        decoration: BoxDecoration(
          color: AppColors.sectionBackground,
          borderRadius: BorderRadius.circular(AppSizes.r8),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryColor, size: AppSizes.sp18),
            SizedBox(width: AppSizes.pw12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: AppSizes.sp10,
                        letterSpacing: 0.8),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: AppColors.textTitle,
                      fontSize: AppSizes.sp14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined,
                color: AppColors.iconMuted, size: AppSizes.sp16),
          ],
        ),
      ),
    );
  }
}

// ── Remind-before selector ───────────────────────────────────────────────────

class _RemindBeforeSelector extends StatelessWidget {
  const _RemindBeforeSelector(
      {required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = [
      (0, l.remindAtTime),
      (15, l.remind15Min),
      (60, l.remind1Hour),
      (1440, l.remind1Day),
      (2880, l.remind2Days),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.remindBeforeLabel,
          style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp11,
              letterSpacing: 0.8),
        ),
        SizedBox(height: AppSizes.h8),
        Wrap(
          spacing: AppSizes.pw8,
          runSpacing: AppSizes.h8,
          children: options.map((opt) {
            final (minutes, label) = opt;
            final selected = value == minutes;
            return GestureDetector(
              onTap: () => onChanged(minutes),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw12, vertical: AppSizes.ph6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor.withValues(alpha: 0.15)
                      : AppColors.sectionBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.inputBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.textMuted,
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Repeat selector ──────────────────────────────────────────────────────────

class _RepeatSelector extends StatelessWidget {
  const _RepeatSelector({
    required this.value,
    required this.interval,
    required this.onTypeChanged,
    required this.onIntervalChanged,
  });
  final ReminderRepeatType value;
  final int interval;
  final ValueChanged<ReminderRepeatType> onTypeChanged;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final types = [
      (ReminderRepeatType.none, l.repeatNone),
      (ReminderRepeatType.daily, l.repeatDaily),
      (ReminderRepeatType.weekly, l.repeatWeekly),
      (ReminderRepeatType.monthly, l.repeatMonthly),
      (ReminderRepeatType.custom, l.repeatCustom),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSizes.pw8,
          runSpacing: AppSizes.h8,
          children: types.map((t) {
            final (type, label) = t;
            final selected = value == type;
            return GestureDetector(
              onTap: () => onTypeChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw12, vertical: AppSizes.ph6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor.withValues(alpha: 0.15)
                      : AppColors.sectionBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.inputBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.textMuted,
                    fontSize: AppSizes.sp12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (value == ReminderRepeatType.custom) ...[
          SizedBox(height: AppSizes.h14),
          Row(
            children: [
              Text(
                l.repeatEveryLabel,
                style: GoogleFonts.manrope(
                    color: AppColors.textMuted, fontSize: AppSizes.sp13),
              ),
              SizedBox(width: AppSizes.pw12),
              _IntervalStepper(
                value: interval,
                onChanged: onIntervalChanged,
              ),
              SizedBox(width: AppSizes.pw8),
              Text(
                l.repeatDaysLabel,
                style: GoogleFonts.manrope(
                    color: AppColors.textMuted, fontSize: AppSizes.sp13),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper(
      {required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBtn(
          icon: Icons.remove,
          onTap: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Container(
          width: AppSizes.w40,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          onTap: value < 365 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppSizes.w32,
        height: AppSizes.w32,
        decoration: BoxDecoration(
          color: AppColors.sectionBackground,
          borderRadius: BorderRadius.circular(AppSizes.r6),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Icon(
          icon,
          size: AppSizes.sp16,
          color: onTap != null ? AppColors.primaryColor : AppColors.iconMuted,
        ),
      ),
    );
  }
}

// ── Notification toggle ──────────────────────────────────────────────────────

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle(
      {required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(
          enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          color: enabled ? AppColors.primaryColor : AppColors.iconMuted,
          size: AppSizes.sp20,
        ),
        SizedBox(width: AppSizes.pw12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.notificationEnabledLabel,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontSize: AppSizes.sp14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                enabled
                    ? l.notificationEnabledDesc
                    : l.notificationDisabledDesc,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onChanged,
          activeThumbColor: AppColors.primaryColor,
          activeTrackColor: AppColors.primaryColor.withValues(alpha: 0.4),
          inactiveTrackColor: AppColors.inputBorder,
          inactiveThumbColor: AppColors.iconMuted,
        ),
      ],
    );
  }
}

// ── Save button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton(
      {required this.saving, required this.isEdit, required this.onSave});
  final bool saving;
  final bool isEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: saving ? null : onSave,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: AppSizes.h52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4BE277), Color(0xFF22C55E)],
          ),
          borderRadius: BorderRadius.circular(AppSizes.r12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: saving
            ? SizedBox(
                width: AppSizes.w20,
                height: AppSizes.w20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.buttonText,
                ),
              )
            : Text(
                isEdit ? l.saveButton : l.createReminderButton,
                style: GoogleFonts.manrope(
                  color: AppColors.buttonText,
                  fontSize: AppSizes.sp15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
