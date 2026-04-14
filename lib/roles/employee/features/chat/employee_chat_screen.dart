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

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.messages,
    required this.displayId,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final String displayId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.senderId == displayId;
        final time = message.createdAt != null
            ? TimeOfDay.fromDateTime(message.createdAt!).format(context)
            : '';

        return Padding(
          padding: EdgeInsets.only(bottom: AppSizes.ph12),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
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
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
              SizedBox(height: AppSizes.h4),
              Text(
                time,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: AppSizes.sp14,
                ),
                onSubmitted: (_) => controller.sendMessage(),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'Type a message',
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
            onTap: controller.isSending ? null : controller.sendMessage,
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
                  : const Icon(Icons.send, color: AppColors.buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
