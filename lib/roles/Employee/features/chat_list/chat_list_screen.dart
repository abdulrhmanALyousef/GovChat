import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/ai_summary_service.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/conversation_model.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/inbox_summary.dart';
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
      backgroundColor: context.colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.colors.cardBackground,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsetsDirectional.only(start: AppSizes.pw16),
          child: Icon(Icons.shield_outlined, color: AppColors.primaryColor),
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
              l.messagesLabel,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          if (controller.conversations.isNotEmpty)
            IconButton(
              icon: const Icon(
                LucideIcons.sparkles,
                color: AppColors.primaryColor,
              ),
              tooltip: l.inboxSummaryTitle,
              onPressed: () => _showInboxSummary(
                context: context,
                conversations: controller.conversations,
                employee: employee,
              ),
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
      separatorBuilder: (context, index) =>
          Divider(color: context.colors.inputBorder, height: 1, thickness: 1),
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
  const _ConversationTile({required this.conversation, required this.employee});

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
            _ConversationAvatar(
              type: conversation.type,
              avatarUrl: conversation.avatarUrl,
            ),
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
                            color: context.colors.textTitle,
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
                            color: context.colors.textMuted,
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
          otherUid: isPrivate ? conversation.otherUid : null,
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
    final senderName = conversation.lastSenderName;
    final msgType = conversation.lastMessageType;

    // No messages yet — lastMessageType is null when no message exists.
    if (msgType == null) {
      return Text(
        l.noMessagesYet,
        style: GoogleFonts.manrope(
          color: context.colors.textMuted,
          fontSize: AppSizes.sp12,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Media messages: show bold black icon + label in a Row.
    IconData? mediaIcon;
    String? mediaLabel;
    switch (msgType) {
      case 'image':
        mediaIcon = LucideIcons.image;
        mediaLabel = l.imageMessage;
      case 'video':
        mediaIcon = LucideIcons.video;
        mediaLabel = l.videoMessage;
      case 'voice':
        mediaIcon = LucideIcons.mic;
        mediaLabel = l.voiceMessage;
    }

    if (mediaIcon != null) {
      return Row(
        children: [
          if (senderName != null && senderName.isNotEmpty)
            Text(
              '$senderName: ',
              style: GoogleFonts.manrope(
                color: AppColors.primaryColor,
                fontSize: AppSizes.sp12,
                fontWeight: FontWeight.w600,
              ),
            ),
          Icon(mediaIcon, color: context.colors.textPrimary, size: AppSizes.sp14),
          const SizedBox(width: 4),
          Text(
            mediaLabel!,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
      );
    }

    // Text message: show decrypted preview or encrypted fallback.
    // We reach here only when msgType != null, meaning messages exist.
    final lastMsg = conversation.lastMessage;
    if (lastMsg == null || lastMsg.isEmpty) {
      return Text(
        l.encryptedMessage,
        style: GoogleFonts.manrope(
          color: context.colors.textMuted,
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
          if (senderName != null && senderName.isNotEmpty)
            TextSpan(
              text: '$senderName: ',
              style: GoogleFonts.manrope(
                color: AppColors.primaryColor,
                fontSize: AppSizes.sp12,
                fontWeight: FontWeight.w600,
              ),
            ),
          TextSpan(
            text: lastMsg,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.type, this.avatarUrl = ''});

  final String type;
  final String avatarUrl;

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
        color: context.colors.sectionBackground,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.inputBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, url) => Icon(
                icon,
                color: AppColors.primaryColor,
                size: AppSizes.sp20,
              ),
              errorWidget: (_, url, error) => Icon(
                icon,
                color: AppColors.primaryColor,
                size: AppSizes.sp20,
              ),
            )
          : Icon(icon, color: AppColors.primaryColor, size: AppSizes.sp20),
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
          color: context.colors.textMuted,
          size: AppSizes.sp10,
        ),
        SizedBox(width: AppSizes.w6),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: context.colors.textMuted,
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
            color: context.colors.textMuted,
            size: AppSizes.sp40,
          ),
          SizedBox(height: AppSizes.h16),
          Text(
            l.noConversationsYet,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inbox Summary ─────────────────────────────────────────────────────────────

void _showInboxSummary({
  required BuildContext context,
  required List<ConversationModel> conversations,
  required EmployeeModel employee,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.cardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
    ),
    builder: (_) => _InboxSummarySheet(
      conversations: conversations,
      employee: employee,
    ),
  );
}

class _InboxSummarySheet extends StatefulWidget {
  const _InboxSummarySheet({
    required this.conversations,
    required this.employee,
  });

  final List<ConversationModel> conversations;
  final EmployeeModel employee;

  @override
  State<_InboxSummarySheet> createState() => _InboxSummarySheetState();
}

class _InboxSummarySheetState extends State<_InboxSummarySheet> {
  InboxSummary? _summary;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final uid = widget.employee.id ?? '';
      if (uid.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final existing =
          await AiSummaryService.instance.fetchInboxSummary(uid);
      if (mounted) {
        setState(() {
          _summary = existing;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final langCode =
          context.read<LocaleProvider>().locale.languageCode;

      // Build the chat descriptors from the conversation list.
      final chats = widget.conversations
          .map((c) => InboxChat(
                title: c.name,
                type: c.type,
                messagesPath: c.messagesCollectionPath,
              ))
          .toList();

      final uid = widget.employee.id ?? '';
      final result = await AiSummaryService.instance.summarizeInbox(
        chats: chats,
        uid: uid,
        languageCode: langCode,
      );
      if (mounted) {
        setState(() {
          _summary = result;
          _generating = false;
        });
      }
    } catch (e) {
      debugPrint('[AI_SUMMARY:INBOX] generate error: $e');
      if (mounted) {
        setState(() {
          _generating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: EdgeInsets.only(
                top: AppSizes.ph12,
                bottom: AppSizes.ph8,
              ),
              child: Container(
                width: AppSizes.w42,
                height: AppSizes.h4,
                decoration: BoxDecoration(
                  color: context.colors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSizes.r4),
                ),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: AppSizes.w8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.inboxSummaryTitle,
                          style: GoogleFonts.manrope(
                            color: context.colors.textTitle,
                            fontWeight: FontWeight.w800,
                            fontSize: AppSizes.sp16,
                          ),
                        ),
                        Text(
                          l.inboxSummarySubtitle,
                          style: GoogleFonts.manrope(
                            color: context.colors.textMuted,
                            fontSize: AppSizes.sp10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_generating)
                    TextButton.icon(
                      onPressed: _generate,
                      icon: Icon(
                        _summary == null
                            ? LucideIcons.zap
                            : LucideIcons.refreshCw,
                        size: 14,
                        color: AppColors.primaryColor,
                      ),
                      label: Text(
                        _summary == null
                            ? l.inboxSummaryGenerate
                            : l.inboxSummaryRegenerate,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp12,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: AppSizes.pw16),
                      child: SizedBox(
                        width: AppSizes.w16,
                        height: AppSizes.h16,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              color: context.colors.inputBorder,
              height: AppSizes.h2,
              thickness: 1,
            ),
            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                    )
                  : _generating
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(height: AppSizes.ph16),
                              Text(
                                l.inboxSummaryAnalysing,
                                style: GoogleFonts.manrope(
                                  color: context.colors.textMuted,
                                  fontSize: AppSizes.sp13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _summary == null
                          ? _InboxSummaryEmpty(onGenerate: _generate)
                          : _InboxSummaryContent(
                              summary: _summary!,
                              error: _error,
                              scrollController: scrollController,
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _InboxSummaryEmpty extends StatelessWidget {
  const _InboxSummaryEmpty({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.inbox,
              color: context.colors.textMuted,
              size: AppSizes.sp40,
            ),
            SizedBox(height: AppSizes.ph16),
            Text(
              l.inboxSummaryEmptyTitle,
              style: GoogleFonts.manrope(
                color: context.colors.textTitle,
                fontWeight: FontWeight.w700,
                fontSize: AppSizes.sp14,
              ),
            ),
            SizedBox(height: AppSizes.ph8),
            Text(
              l.inboxSummaryEmptySubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp13,
              ),
            ),
            SizedBox(height: AppSizes.ph24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: Text(
                  l.inboxSummaryGenerateButton,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.sp14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonBackground,
                  foregroundColor: AppColors.buttonText,
                  padding: EdgeInsets.symmetric(vertical: AppSizes.ph14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxSummaryContent extends StatelessWidget {
  const _InboxSummaryContent({
    required this.summary,
    required this.scrollController,
    this.error,
  });

  final InboxSummary summary;
  final ScrollController scrollController;
  final String? error;

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        AppSizes.ph8,
        AppSizes.pw16,
        AppSizes.ph24,
      ),
      children: [
        if (error != null) ...[
          Container(
            margin: EdgeInsets.only(bottom: AppSizes.ph12),
            padding: EdgeInsets.all(AppSizes.pw16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.r12),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              error!,
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontSize: AppSizes.sp12,
              ),
            ),
          ),
        ],
        _InboxSection(
          icon: LucideIcons.sparkles,
          title: l.inboxSummaryHighlights,
          body: summary.highlights,
        ),
        _InboxSection(
          icon: LucideIcons.alertTriangle,
          title: l.inboxSummaryUrgent,
          body: summary.urgentItems,
        ),
        _InboxSection(
          icon: LucideIcons.checkCircle,
          title: l.inboxSummaryDecisions,
          body: summary.decisions,
        ),
        _InboxSection(
          icon: LucideIcons.clipboardList,
          title: l.inboxSummaryPending,
          body: summary.pendingItems,
        ),
        _InboxSection(
          icon: LucideIcons.messageSquare,
          title: l.inboxSummaryPerChat,
          body: summary.perChatBreakdown,
        ),
        _InboxSection(
          icon: LucideIcons.barChart2,
          title: l.inboxSummaryTrends,
          body: summary.trends,
        ),
        SizedBox(height: AppSizes.ph8),
        Text(
          l.inboxSummaryGeneratedAt(_formatDate(summary.generatedAt)),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: context.colors.textMuted,
            fontSize: AppSizes.sp11,
          ),
        ),
      ],
    );
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.ph12),
      padding: EdgeInsets.all(AppSizes.pw16),
      decoration: BoxDecoration(
        color: context.colors.sectionBackground,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: context.colors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryColor, size: AppSizes.sp14),
              SizedBox(width: AppSizes.w6),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.sp12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.ph8),
          Text(
            body.isNotEmpty ? body : '—',
            style: GoogleFonts.manrope(
              color: context.colors.textPrimary,
              fontSize: AppSizes.sp13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

