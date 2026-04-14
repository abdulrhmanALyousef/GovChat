import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/chat_message.dart';
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
        leading: Padding(
          padding: EdgeInsets.only(left: AppSizes.pw16),
          child: Icon(Icons.shield_outlined, color: AppColors.primaryColor),
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
            icon: const Icon(Icons.logout, color: AppColors.textPrimary),
            onPressed: () async {
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
                  displayId: controller.displayId,
                  scrollController: controller.scrollController,
                  onEditTap: controller.startEditing,
                ),
              ),
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
    required this.displayId,
    required this.scrollController,
    required this.onEditTap,
  });

  final List<ChatMessage> messages;
  final String displayId;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onEditTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageItem(
          message: message,
          isMine: message.senderId == displayId,
          onEditTap: onEditTap,
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
  });

  final ChatMessage message;
  final bool isMine;
  final ValueChanged<ChatMessage> onEditTap;

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
                  ? () => _showEditSheet(context)
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
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.r20),
        ),
      ),
      builder: (_) => _EditSheet(
        onEdit: () {
          Navigator.pop(context);
          onEditTap(message);
        },
      ),
    );
  }
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────────

class _EditSheet extends StatelessWidget {
  const _EditSheet({required this.onEdit});

  final VoidCallback onEdit;

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
          SizedBox(height: AppSizes.ph16),
        ],
      ),
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
