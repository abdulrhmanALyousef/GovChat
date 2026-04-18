import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/chat_message.dart'
    show ChatMessage, MessageStatus;
import '../../../../models/employee_model.dart';
import 'controller/chat_controller.dart';

class EmployeeChatScreen extends StatelessWidget {
  const EmployeeChatScreen({
    super.key,
    required this.employee,
    this.chatTitle,
    this.chatSubtitle,
    this.messagesPath,
  });

  final EmployeeModel employee;

  /// Override the AppBar title (defaults to employee's department name).
  final String? chatTitle;

  /// Override the AppBar subtitle (defaults to 'GROUP CHAT').
  final String? chatSubtitle;

  /// Override the Firestore messages collection path (for private chats).
  final String? messagesPath;

  @override
  Widget build(BuildContext context) {
    final deptKey = employee.departmentId.trim().isNotEmpty
        ? employee.departmentId.trim()
        : employee.department.trim().replaceAll(' ', '_').toLowerCase();

    return ChangeNotifierProvider(
      create: (_) => ChatController(
        organizationId: employee.organizationId,
        departmentId: deptKey,
        departmentName: employee.department,
        displayId: employee.displayId,
        messagesPath: messagesPath,
      ),
      child: _ChatView(
        employee: employee,
        chatTitle: chatTitle,
        chatSubtitle: chatSubtitle,
      ),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _ChatView extends StatelessWidget {
  const _ChatView({
    required this.employee,
    this.chatTitle,
    this.chatSubtitle,
  });

  final EmployeeModel employee;
  final String? chatTitle;
  final String? chatSubtitle;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final title = chatTitle ?? employee.department;
    final subtitle = chatSubtitle ?? 'GROUP CHAT';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textTitle,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp16,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontSize: AppSizes.sp10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirmed = await _showLogoutDialog(context);
              if (!confirmed || !context.mounted) return;
              await SessionManager.instance.logout(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.scaffoldBackground,
                AppColors.sectionBackground.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: AppSizes.ph12),
              _EncryptionPill(),
              SizedBox(height: AppSizes.ph12),
              Expanded(
                child: _MessagesList(
                  messages: controller.messages,
                  myDisplayId: controller.displayId,
                  scrollController: controller.scrollController,
                  onEditTap: controller.startEditing,
                  onDeleteTap: controller.deleteMessage,
                ),
              ),
              _TypingIndicator(typingIds: controller.typingDisplayIds),
              _InputBar(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Messages list ────────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.messages,
    required this.myDisplayId,
    required this.scrollController,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final List<ChatMessage> messages;
  final String myDisplayId;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onEditTap;
  final ValueChanged<ChatMessage> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.senderId == myDisplayId;
        return _MessageItem(
          message: message,
          isMine: isMine,
          status: isMine ? message.statusFor(myDisplayId) : null,
          onEditTap: onEditTap,
          onDeleteTap: onDeleteTap,
        );
      },
    );
  }
}

// ─── Single message item ──────────────────────────────────────────────────────

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.isMine,
    required this.onEditTap,
    required this.onDeleteTap,
    this.status,
  });

  final ChatMessage message;
  final bool isMine;
  final MessageStatus? status;
  final ValueChanged<ChatMessage> onEditTap;
  final ValueChanged<ChatMessage> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? TimeOfDay.fromDateTime(message.createdAt!).format(context)
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.ph12),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.senderId,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp10,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: AppSizes.h4),
          Align(
            alignment:
                isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: GestureDetector(
              onLongPress: isMine
                  ? () => _showActionsSheet(context)
                  : null,
              child: Container(
                constraints: BoxConstraints(maxWidth: AppSizes.w240),
                padding: EdgeInsets.all(AppSizes.ph14),
                decoration: BoxDecoration(
                  color: isMine
                      ? AppColors.primaryColor
                      : AppColors.sectionBackground,
                  borderRadius: BorderRadius.circular(AppSizes.r16),
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.manrope(
                    color: isMine
                        ? AppColors.buttonText
                        : AppColors.textPrimary,
                    fontSize: AppSizes.sp14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppSizes.h4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(
                time,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp10,
                ),
              ),
              if (message.isEdited) ...[
                SizedBox(width: AppSizes.w6),
                Text(
                  '· edited',
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (status != null) ...[
                SizedBox(width: AppSizes.w6),
                _StatusIcon(status: status!),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _canDelete() {
    final createdAt = message.createdAt;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt) <=
        const Duration(minutes: 5);
  }

  void _showActionsSheet(BuildContext context) {
    final deletable = _canDelete();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.r20),
        ),
      ),
      builder: (_) => _MessageActionsSheet(
        onEdit: () {
          Navigator.pop(context);
          onEditTap(message);
        },
        onDelete: deletable
            ? () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              }
            : null,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _DeleteConfirmationDialog(
        onConfirm: () {
          Navigator.pop(context);
          onDeleteTap(message);
        },
      ),
    );
  }
}

// ─── Status icon ─────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: AppSizes.sp12,
          color: AppColors.textMuted,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: AppSizes.sp12,
          color: AppColors.textMuted,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: AppSizes.sp12,
          color: AppColors.primaryColor,
        );
    }
  }
}

// ─── Message actions bottom sheet ────────────────────────────────────────────

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({required this.onEdit, this.onDelete});

  final VoidCallback onEdit;

  /// Null when the 5-minute deletion window has expired.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: AppSizes.w42,
            height: AppSizes.h4,
            margin: EdgeInsets.symmetric(vertical: AppSizes.ph12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppSizes.r4),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.edit_outlined,
              color: AppColors.primaryColor,
              size: AppSizes.sp20,
            ),
            title: Text(
              'Edit Message',
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: AppSizes.sp14,
              ),
            ),
            onTap: onEdit,
          ),
          if (onDelete != null)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: AppSizes.sp20,
              ),
              title: Text(
                'Delete Message',
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.sp14,
                ),
              ),
              onTap: onDelete,
            ),
          SizedBox(height: AppSizes.ph16),
        ],
      ),
    );
  }
}

// ─── Delete confirmation dialog ───────────────────────────────────────────────

class _DeleteConfirmationDialog extends StatelessWidget {
  const _DeleteConfirmationDialog({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r16),
      ),
      title: Text(
        'Delete Message',
        style: GoogleFonts.manrope(
          color: AppColors.textTitle,
          fontWeight: FontWeight.w800,
          fontSize: AppSizes.sp16,
        ),
      ),
      content: Text(
        'This message will be permanently removed for everyone. This action cannot be undone.',
        style: GoogleFonts.manrope(
          color: AppColors.textMuted,
          fontSize: AppSizes.sp13,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: AppSizes.sp14,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            'Delete',
            style: GoogleFonts.manrope(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: AppSizes.sp14,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Edit context strip ───────────────────────────────────────────────────────

class _EditContextStrip extends StatelessWidget {
  const _EditContextStrip({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final msg = controller.editingMessage;
    if (msg == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph8,
      ),
      color: AppColors.sectionBackground,
      child: Row(
        children: [
          Container(
            width: AppSizes.w2,
            height: AppSizes.h40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(AppSizes.r4),
            ),
          ),
          SizedBox(width: AppSizes.w12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing message',
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontSize: AppSizes.sp11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSizes.h2),
                Text(
                  msg.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: AppColors.textMuted,
              size: AppSizes.sp20,
            ),
            onPressed: controller.cancelEditing,
          ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.typingIds});

  final List<String> typingIds;

  @override
  Widget build(BuildContext context) {
    if (typingIds.isEmpty) return const SizedBox.shrink();

    final label = typingIds.length == 1
        ? '${typingIds.first} is typing'
        : '${typingIds.length} people are typing';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        0,
        AppSizes.pw16,
        AppSizes.ph8,
      ),
      child: Row(
        children: [
          const _TypingDots(),
          SizedBox(width: AppSizes.w8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> {
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = _dotCount % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '.' * _dotCount,
      style: GoogleFonts.manrope(
        color: AppColors.primaryColor,
        fontSize: AppSizes.sp16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─── Encryption pill ──────────────────────────────────────────────────────────

class _EncryptionPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph8,
      ),
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        borderRadius: BorderRadius.circular(AppSizes.r30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            color: AppColors.primaryColor,
            size: AppSizes.sp14,
          ),
          SizedBox(width: AppSizes.w8),
          Text(
            'END-TO-END ENCRYPTED CHANNEL',
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: AppSizes.sp10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditContextStrip(controller: controller),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSizes.pw16,
            AppSizes.ph12,
            AppSizes.pw16,
            AppSizes.ph16,
          ),
          color: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw16,
                    vertical: AppSizes.ph12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppSizes.r16),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: TextField(
                    controller: controller.messageController,
                    focusNode: controller.inputFocusNode,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: AppSizes.sp14,
                    ),
                    onChanged: controller.onTextChanged,
                    onSubmitted: (_) => controller.isEditing
                        ? controller.confirmEdit()
                        : controller.sendMessage(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: controller.isEditing
                          ? 'Edit message'
                          : 'Type a message',
                      hintStyle: GoogleFonts.manrope(
                        color: AppColors.hintText,
                        fontSize: AppSizes.sp14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSizes.w12),
              GestureDetector(
                onTap: controller.isSending
                    ? null
                    : controller.isEditing
                        ? controller.confirmEdit
                        : controller.sendMessage,
                child: Container(
                  height: AppSizes.h48,
                  width: AppSizes.h48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: controller.isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.buttonText,
                          ),
                        )
                      : Icon(
                          controller.isEditing ? Icons.check : Icons.send,
                          color: AppColors.buttonText,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<bool> _showLogoutDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.r20),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSizes.pw24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.ph16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: AppSizes.sp28,
                  ),
                ),
                SizedBox(height: AppSizes.h16),
                Text(
                  'Sign Out',
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: AppSizes.sp18,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                Text(
                  'You will be signed out and your local session will be cleared from this device.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: AppSizes.h24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.inputBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppSizes.ph14,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSizes.w12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r12),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: AppSizes.ph14,
                          ),
                        ),
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.manrope(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}
