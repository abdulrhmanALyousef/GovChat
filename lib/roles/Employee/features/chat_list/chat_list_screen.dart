import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/conversation_model.dart';
import '../../../../models/employee_model.dart';
import '../chat/employee_chat_screen.dart';
import '../new_chat/new_chat_screen.dart';
import 'controller/chat_list_controller.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatListController(employee: employee),
      child: _ChatListView(employee: employee),
    );
  }
}

class _ChatListView extends StatelessWidget {
  const _ChatListView({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatListController>();
    final l = AppLocalizations.of(context)!;

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
              employee.name,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp16,
              ),
            ),
            Text(
              l.messagesLabel,
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
            tooltip: l.signOutButton,
            onPressed: () async {
              final confirmed = await _showLogoutDialog(context, l);
              if (!confirmed || !context.mounted) return;
              await SessionManager.instance.logout(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _NewChatButton(employee: employee),
            Expanded(
              child: controller.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    )
                  : controller.conversations.isEmpty
                      ? _EmptyState()
                      : _ConversationList(
                          conversations: controller.conversations,
                          employee: employee,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        AppSizes.ph16,
        AppSizes.pw16,
        0,
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewChatScreen(currentEmployee: employee),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppSizes.ph14,
            horizontal: AppSizes.pw16,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(AppSizes.r16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_outlined,
                color: AppColors.buttonText,
                size: AppSizes.sp20,
              ),
              SizedBox(width: AppSizes.w8),
              Text(
                l.newChatButton,
                style: GoogleFonts.manrope(
                  color: AppColors.buttonText,
                  fontWeight: FontWeight.w800,
                  fontSize: AppSizes.sp14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.employee,
  });

  final List<ConversationModel> conversations;
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph12,
      ),
      itemCount: conversations.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.inputBorder,
        height: 1,
        thickness: 1,
      ),
      itemBuilder: (context, index) {
        return _ConversationTile(
          conversation: conversations[index],
          employee: employee,
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.employee,
  });

  final ConversationModel conversation;
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(conversation.lastMessageTime);

    return InkWell(
      onTap: () => _openChat(context),
      borderRadius: BorderRadius.circular(AppSizes.r12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppSizes.ph12,
          horizontal: AppSizes.pw8,
        ),
        child: Row(
          children: [
            _ConversationAvatar(type: conversation.type),
            SizedBox(width: AppSizes.w12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conversation.name,
                          style: GoogleFonts.manrope(
                            color: AppColors.textTitle,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.sp14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeLabel != null)
                        Text(
                          timeLabel,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: AppSizes.sp11,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: AppSizes.h4),
                  _LastMessagePreview(conversation: conversation),
                  SizedBox(height: AppSizes.h4),
                  _ConversationTypeBadge(type: conversation.type),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isPrivate = conversation.type == 'private';
    final isOrg = conversation.type == 'organization';
    final isGroup = conversation.type == 'group';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeChatScreen(
          employee: employee,
          chatTitle: (isPrivate || isOrg || isGroup) ? conversation.name : null,
          chatSubtitle: isPrivate
              ? l.privateChatSubtitle
              : isOrg
                  ? l.orgChatLabel
                  : isGroup
                      ? l.groupChatLabel
                      : null,
          messagesPath: (isPrivate || isOrg || isGroup)
              ? conversation.messagesCollectionPath
              : null,
        ),
      ),
    );
  }

  String? _formatTime(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _LastMessagePreview extends StatelessWidget {
  const _LastMessagePreview({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lastMsg = conversation.lastMessage;
    final senderId = conversation.lastSenderId;

    if (lastMsg == null || lastMsg.isEmpty) {
      return Text(
        l.noMessagesYet,
        style: GoogleFonts.manrope(
          color: AppColors.textMuted,
          fontSize: AppSizes.sp12,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          if (senderId != null && senderId.isNotEmpty)
            TextSpan(
              text: '$senderId: ',
              style: GoogleFonts.manrope(
                color: AppColors.primaryColor,
                fontSize: AppSizes.sp12,
                fontWeight: FontWeight.w600,
              ),
            ),
          TextSpan(
            text: lastMsg,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final icon = type == 'organization'
        ? Icons.corporate_fare_outlined
        : type == 'department'
            ? Icons.groups_outlined
            : type == 'group'
                ? Icons.group_outlined
                : Icons.chat_bubble_outline;

    return Container(
      height: AppSizes.h48,
      width: AppSizes.w48,
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Icon(icon, color: AppColors.primaryColor, size: AppSizes.sp20),
    );
  }
}

class _ConversationTypeBadge extends StatelessWidget {
  const _ConversationTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label = type == 'organization'
        ? l.orgChatLabel
        : type == 'department'
            ? l.groupChatLabel
            : type == 'group'
                ? l.projectGroupLabel
                : l.privateChatLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline,
          color: AppColors.textMuted,
          size: AppSizes.sp10,
        ),
        SizedBox(width: AppSizes.w6),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppColors.textMuted,
            size: AppSizes.sp40,
          ),
          SizedBox(height: AppSizes.h16),
          Text(
            l.noConversationsYet,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _showLogoutDialog(BuildContext context, AppLocalizations l) async {
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
                  l.signOutButton,
                  style: GoogleFonts.manrope(
                    color: AppColors.textTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: AppSizes.sp18,
                  ),
                ),
                SizedBox(height: AppSizes.h8),
                Text(
                  l.signOutConfirm,
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
                          l.cancelButton,
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
                          l.signOutButton,
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