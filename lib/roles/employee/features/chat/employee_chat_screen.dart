import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_screenshot_blocker/flutter_screenshot_blocker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/ai_summary_service.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/chat_summary.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/chat_message.dart'
    show ChatMessage, MessageStatus, MessageType;
import '../../../../models/employee_model.dart';
import 'controller/chat_controller.dart';
import 'widgets/chat_media_bubbles.dart';

class EmployeeChatScreen extends StatelessWidget {
  const EmployeeChatScreen({
    super.key,
    required this.employee,
    this.chatTitle,
    this.chatSubtitle,
    this.messagesPath,
    this.otherUid,
  });

  final EmployeeModel employee;
  final String? chatTitle;
  final String? chatSubtitle;
  final String? messagesPath;

  /// For private chats: the UID of the other participant.
  /// When set, the app bar streams this employee's profile for a live name.
  final String? otherUid;

  @override
  Widget build(BuildContext context) {
    final deptKey = employee.departmentId.trim().isNotEmpty
        ? employee.departmentId.trim()
        : employee.department.trim().replaceAll(' ', '_').toLowerCase();

    final isPrivateChat =
        messagesPath != null && messagesPath!.contains('/private_chats/');

    return ChangeNotifierProvider(
      create: (_) => ChatController(
        organizationId: employee.organizationId,
        departmentId: deptKey,
        departmentName: employee.department,
        displayId: employee.displayId,
        employeeUid: employee.id ?? '',
        messagesPath: messagesPath,
      ),
      child: _ChatView(
        employee: employee,
        chatTitle: chatTitle,
        chatSubtitle: chatSubtitle,
        isPrivateChat: isPrivateChat,
        otherUid: otherUid,
      ),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.employee,
    this.chatTitle,
    this.chatSubtitle,
    this.isPrivateChat = false,
    this.otherUid,
  });

  final EmployeeModel employee;
  final String? chatTitle;
  final String? chatSubtitle;
  final bool isPrivateChat;
  final String? otherUid;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final l = AppLocalizations.of(context)!;
    final fallbackTitle = widget.chatTitle ?? widget.employee.department;
    final subtitle = widget.chatSubtitle ?? l.groupChatTitle;

    return ScreenshotBlockerWidget(
      detectScreenshots: false,
      child: Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.colors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: context.colors.textTitle,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.otherUid != null && widget.otherUid!.isNotEmpty
            ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('employees')
                    .doc(widget.otherUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final name = snapshot.data?.data()?['name'] as String? ?? '';
                  final title = name.isNotEmpty ? name : fallbackTitle;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          color: context.colors.textTitle,
                          fontWeight: FontWeight.w800,
                          fontSize: AppSizes.sp16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          color: context.colors.textMuted,
                          fontSize: AppSizes.sp10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  );
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fallbackTitle,
                    style: GoogleFonts.manrope(
                      color: context.colors.textTitle,
                      fontWeight: FontWeight.w800,
                      fontSize: AppSizes.sp16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      color: context.colors.textMuted,
                      fontSize: AppSizes.sp10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.sparkles, color: context.colors.textTitle),
            tooltip: 'Summarize Chat',
            onPressed: () => _showSummarizeSheet(
              context,
              messages: controller.messages,
              messagesPath: controller.effectiveMessagesPath,
              chatTitle: fallbackTitle,
            ),
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
                context.colors.scaffoldBackground,
                context.colors.sectionBackground.withValues(alpha: 0.6),
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
                  controller: controller,
                  isPrivateChat: widget.isPrivateChat,
                ),
              ),
              if (controller.typingDisplayIds.isNotEmpty)
                _TypingIndicator(typingIds: controller.typingDisplayIds),
              if (controller.errorMessage != null)
                _ErrorBanner(
                  message: controller.errorMessage!,
                  onDismiss: controller.clearError,
                  onRetry: controller.errorMessage!.contains('Encryption')
                      ? controller.retryEncryptionInit
                      : null,
                ),
              _InputBar(controller: controller),
            ],
          ),
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
    required this.controller,
    required this.isPrivateChat,
  });

  final List<ChatMessage> messages;
  final String myDisplayId;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onEditTap;
  final ValueChanged<ChatMessage> onDeleteTap;
  final ChatController controller;
  final bool isPrivateChat;

  @override
  Widget build(BuildContext context) {
    // Hide messages that are still encrypted or failed decryption.
    final visible = messages.where((m) {
      if (m.text.startsWith('[Decryption error:')) return false;
      if (m.isEncrypted && m.text.isEmpty) return false;
      return true;
    }).toList();

    // Extra item at top for loading indicator when paginating.
    final hasLoadingHeader = controller.isLoadingMore;
    final totalItems = visible.length + (hasLoadingHeader ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      itemCount: totalItems,
      // Keeps off-screen items alive to avoid rebuild cost.
      cacheExtent: 500,
      // Stable keys prevent unnecessary rebuilds when the list shifts.
      findChildIndexCallback: (key) {
        if (key is ValueKey<String>) {
          final idx = visible.indexWhere((m) => m.id == key.value);
          return idx == -1 ? null : idx + (hasLoadingHeader ? 1 : 0);
        }
        return null;
      },
      itemBuilder: (context, index) {
        // Loading indicator at position 0 when paginating.
        if (hasLoadingHeader && index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.ph12),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          );
        }
        final msgIndex = hasLoadingHeader ? index - 1 : index;
        final message = visible[msgIndex];
        final isMine = message.senderId == myDisplayId;
        final profile = controller.getSenderProfile(
          message.senderUid,
          message.senderId,
        );
        return _MessageItem(
          key: message.id != null ? ValueKey(message.id) : null,
          message: message,
          isMine: isMine,
          status: isMine ? message.statusFor(myDisplayId) : null,
          onEditTap: onEditTap,
          onDeleteTap: onDeleteTap,
          senderName: profile.name,
          senderAvatarUrl: profile.avatarUrl,
          isPrivateChat: isPrivateChat,
        );
      },
    );
  }
}

// ─── Single message item ──────────────────────────────────────────────────────

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    super.key,
    required this.message,
    required this.isMine,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.isPrivateChat,
    this.status,
  });

  final ChatMessage message;
  final bool isMine;
  final MessageStatus? status;
  final ValueChanged<ChatMessage> onEditTap;
  final ValueChanged<ChatMessage> onDeleteTap;
  final String senderName;
  final String senderAvatarUrl;
  final bool isPrivateChat;

  // For media bubbles we skip the inner padding so they fill edge-to-edge.
  bool get _isMediaBubble => message.messageType != MessageType.text;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? TimeOfDay.fromDateTime(message.createdAt!).format(context)
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.ph12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Avatar on the left for other's messages
          if (!isMine) ...[
            _MessageAvatar(avatarUrl: senderAvatarUrl, name: senderName),
            SizedBox(width: AppSizes.w8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name label — group chat only, not for own messages
                if (!isMine && !isPrivateChat)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppSizes.h4),
                    child: Text(
                      message.senderRole == 'admin'
                          ? AppLocalizations.of(context)!.adminLabel
                          : senderName,
                      style: GoogleFonts.manrope(
                        color: message.senderRole == 'admin'
                            ? const Color(0xFFEF4444)
                            : context.colors.textMuted,
                        fontSize: AppSizes.sp10,
                        fontWeight: message.senderRole == 'admin'
                            ? FontWeight.w700
                            : FontWeight.normal,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),

                // Bubble
                Align(
                  alignment: isMine
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: GestureDetector(
                    onLongPress: isMine
                        ? () => _showActionsSheet(context)
                        : null,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: AppSizes.w240),
                      padding: _isMediaBubble
                          ? EdgeInsets.zero
                          : EdgeInsets.all(AppSizes.ph14),
                      decoration: BoxDecoration(
                        color: isMine
                            ? AppColors.primaryColor
                            : context.colors.sectionBackground,
                        borderRadius: BorderRadius.circular(AppSizes.r16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildContent(context),
                    ),
                  ),
                ),

                // Timestamp row
                SizedBox(height: AppSizes.h4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.manrope(
                        color: context.colors.textMuted,
                        fontSize: AppSizes.sp10,
                      ),
                    ),
                    if (message.isEdited) ...[
                      SizedBox(width: AppSizes.w6),
                      Text(
                        AppLocalizations.of(context)!.editedLabel,
                        style: GoogleFonts.manrope(
                          color: context.colors.textMuted,
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
          ),
          // Avatar on the right for own messages
          if (isMine) ...[
            SizedBox(width: AppSizes.w8),
            _MessageAvatar(avatarUrl: senderAvatarUrl, name: senderName),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.messageType) {
      case MessageType.image:
        return ChatImageBubble(
          mediaUrl: message.mediaUrl ?? '',
          isMine: isMine,
        );
      case MessageType.video:
        return ChatVideoBubble(
          mediaUrl: message.mediaUrl ?? '',
          isMine: isMine,
          mediaDuration: message.mediaDuration,
        );
      case MessageType.voice:
        return ChatVoiceBubble(
          mediaUrl: message.mediaUrl ?? '',
          isMine: isMine,
          mediaDuration: message.mediaDuration,
        );
      case MessageType.text:
        return Text(
          message.text,
          textDirection: Directionality.of(context),
          style: GoogleFonts.manrope(
            color: isMine ? AppColors.buttonText : context.colors.textPrimary,
            fontSize: AppSizes.sp14,
            height: 1.4,
          ),
        );
    }
  }

  bool _canDelete() {
    final createdAt = message.createdAt;
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt) <= const Duration(minutes: 5);
  }

  void _showActionsSheet(BuildContext context) {
    final deletable = _canDelete();
    final canEdit = message.messageType == MessageType.text;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
      ),
      builder: (_) => _MessageActionsSheet(
        onEdit: canEdit
            ? () {
                Navigator.pop(context);
                onEditTap(message);
              }
            : null,
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

// ─── Status icon ──────────────────────────────────────────────────────────────

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
          color: context.colors.textMuted,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: AppSizes.sp12,
          color: context.colors.textMuted,
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

// ─── Message avatar ──────────────────────────────────────────────────────────

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.avatarUrl, required this.name});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
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
              placeholder: (_, url) => Center(
                child: Text(
                  initial,
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.sp10,
                  ),
                ),
              ),
              errorWidget: (_, url, error) => Center(
                child: Text(
                  initial,
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: AppSizes.sp10,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.manrope(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.sp10,
                ),
              ),
            ),
    );
  }
}

// ─── Message actions bottom sheet ────────────────────────────────────────────

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.w42,
            height: AppSizes.h4,
            margin: EdgeInsets.symmetric(vertical: AppSizes.ph12),
            decoration: BoxDecoration(
              color: context.colors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppSizes.r4),
            ),
          ),
          if (onEdit != null)
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: AppColors.primaryColor,
                size: AppSizes.sp20,
              ),
              title: Text(
                l.editMessageTitle,
                style: GoogleFonts.manrope(
                  color: context.colors.textPrimary,
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
                l.deleteMessageTitle,
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
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: context.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r16),
      ),
      title: Text(
        l.deleteMessageTitle,
        style: GoogleFonts.manrope(
          color: context.colors.textTitle,
          fontWeight: FontWeight.w800,
          fontSize: AppSizes.sp16,
        ),
      ),
      content: Text(
        l.deleteMessageConfirm,
        style: GoogleFonts.manrope(
          color: context.colors.textMuted,
          fontSize: AppSizes.sp13,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l.cancelButton,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: AppSizes.sp14,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            l.deleteButton,
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
    final l = AppLocalizations.of(context)!;
    final msg = controller.editingMessage;
    if (msg == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph8,
      ),
      color: context.colors.sectionBackground,
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
                  l.editingMessage,
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
                    color: context.colors.textMuted,
                    fontSize: AppSizes.sp12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: context.colors.textMuted,
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
    final l = AppLocalizations.of(context)!;
    final label = typingIds.length == 1
        ? l.isTypingSingle(typingIds.first)
        : l.arePeopleTyping(typingIds.length);

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
              color: context.colors.textMuted,
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
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph8,
      ),
      decoration: BoxDecoration(
        color: context.colors.sectionBackground,
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
            l.endToEndEncryptedChannel,
            style: GoogleFonts.manrope(
              color: context.colors.textPrimary,
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
    final isRecording = controller.isRecording;
    final isUploading = controller.isUploadingMedia;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRecording) _EditContextStrip(controller: controller),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSizes.pw16,
            AppSizes.ph12,
            AppSizes.pw16,
            AppSizes.ph16,
          ),
          color: Colors.transparent,
          child: isRecording
              ? _RecordingBar(controller: controller)
              : isUploading
              ? _UploadingBar()
              : _TextInputRow(controller: controller),
        ),
      ],
    );
  }
}

// ─── Normal text + media input row ────────────────────────────────────────────

class _TextInputRow extends StatelessWidget {
  const _TextInputRow({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEditing = controller.isEditing;

    final mediaEnabled = controller.mediaSharingEnabled;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Attach button (hidden in edit mode)
        if (!isEditing) ...[
          Opacity(
            opacity: mediaEnabled ? 1.0 : 0.4,
            child: _CircleIconButton(
              icon: mediaEnabled ? LucideIcons.paperclip : LucideIcons.lock,
              color: Colors.white,
              backgroundColor: context.colors.cardBackground,
              onTap: () {
                if (!mediaEnabled) {
                  _showMediaDisabledSnackBar(context, l);
                  return;
                }
                _showAttachmentSheet(context, controller, l);
              },
            ),
          ),
          SizedBox(width: AppSizes.w8),
        ],

        // Text field
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.pw16,
              vertical: AppSizes.ph12,
            ),
            decoration: BoxDecoration(
              color: context.colors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.r16),
              border: Border.all(color: context.colors.inputBorder),
            ),
            child: TextField(
              controller: controller.messageController,
              focusNode: controller.inputFocusNode,
              style: GoogleFonts.manrope(
                color: context.colors.textPrimary,
                fontSize: AppSizes.sp14,
              ),
              onChanged: (v) {
                controller.onTextChanged(v);
                // trigger rebuild for send/mic toggle
                (context as Element).markNeedsBuild();
              },
              onSubmitted: (_) => isEditing
                  ? controller.confirmEdit()
                  : controller.sendMessage(),
              maxLines: null,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: isEditing ? l.editMessageHint : l.typeAMessage,
                hintStyle: GoogleFonts.manrope(
                  color: context.colors.hintText,
                  fontSize: AppSizes.sp14,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        SizedBox(width: AppSizes.w8),

        // Send / Confirm edit / Mic button
        if (isEditing)
          _GradientActionButton(
            isSending: controller.isSending,
            icon: Icons.check,
            onTap: controller.confirmEdit,
          )
        else
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.messageController,
            builder: (ctx, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return hasText
                  ? _GradientActionButton(
                      isSending: controller.isSending,
                      icon: Icons.send,
                      onTap: controller.sendMessage,
                    )
                  : Opacity(
                      opacity: mediaEnabled ? 1.0 : 0.4,
                      child: _CircleIconButton(
                        icon: mediaEnabled ? LucideIcons.mic : LucideIcons.micOff,
                        color: Colors.white,
                        backgroundColor: AppColors.primaryColor.withValues(
                          alpha: 0.15,
                        ),
                        onTap: () {
                          if (!mediaEnabled) {
                            _showMediaDisabledSnackBar(context, l);
                            return;
                          }
                          controller.startVoiceRecording();
                        },
                      ),
                    );
            },
          ),
      ],
    );
  }
}

// ─── Recording bar ────────────────────────────────────────────────────────────

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.controller});

  final ChatController controller;

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cancel
        _CircleIconButton(
          icon: Icons.close_rounded,
          color: AppColors.error,
          backgroundColor: AppColors.error.withValues(alpha: 0.15),
          onTap: () => controller.cancelVoiceRecording(),
        ),
        SizedBox(width: AppSizes.w12),

        // Waveform + timer
        Expanded(
          child: Container(
            height: AppSizes.h48,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.pw12),
            decoration: BoxDecoration(
              color: context.colors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.r16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                // Pulsing dot
                _PulsingDot(),
                SizedBox(width: AppSizes.w8),
                // Timer
                Text(
                  _formatDuration(controller.recordingSeconds),
                  style: GoogleFonts.manrope(
                    color: AppColors.error,
                    fontSize: AppSizes.sp13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: AppSizes.w12),
                // Animated waveform
                Expanded(child: RecordingWaveform()),
              ],
            ),
          ),
        ),

        SizedBox(width: AppSizes.w12),

        // Send recording
        _GradientActionButton(
          isSending: false,
          icon: Icons.send_rounded,
          onTap: controller.stopAndSendVoiceRecording,
        ),
      ],
    );
  }
}

// ─── Uploading bar ────────────────────────────────────────────────────────────

class _UploadingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: AppSizes.h48,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: context.colors.inputBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: AppSizes.sp16,
            height: AppSizes.sp16,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(width: AppSizes.w12),
          Text(
            l.uploadingMedia,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Media disabled snackbar ──────────────────────────────────────────────────

void _showMediaDisabledSnackBar(BuildContext context, AppLocalizations l) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l.mediaSharingDisabledMessage,
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: AppSizes.sp13,
        ),
      ),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r12),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

// ─── Attachment bottom sheet ──────────────────────────────────────────────────

void _showAttachmentSheet(
  BuildContext context,
  ChatController controller,
  AppLocalizations l,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.cardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
    ),
    builder: (sheetCtx) {
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
                color: context.colors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSizes.r4),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.pw16,
                vertical: AppSizes.ph8,
              ),
              child: Text(
                l.mediaAttachmentTitle,
                style: GoogleFonts.manrope(
                  color: context.colors.textTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.sp14,
                ),
              ),
            ),
            SizedBox(height: AppSizes.h8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: LucideIcons.camera,
                  label: l.takePhotoOption,
                  color: Colors.white,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    controller.captureAndSendImage();
                  },
                ),
                _AttachOption(
                  icon: LucideIcons.image,
                  label: l.choosePhotoOption,
                  color: Colors.white,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    controller.pickAndSendImage();
                  },
                ),
              ],
            ),
            SizedBox(height: AppSizes.ph16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: LucideIcons.video,
                  label: l.recordVideoOption,
                  color: Colors.white,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    controller.captureAndSendVideo();
                  },
                ),
                _AttachOption(
                  icon: LucideIcons.film,
                  label: l.chooseVideoOption,
                  color: Colors.white,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    controller.pickAndSendVideo();
                  },
                ),
              ],
            ),
            SizedBox(height: AppSizes.ph24),
          ],
        ),
      );
    },
  );
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.h56,
            height: AppSizes.h56,
            decoration: BoxDecoration(
              color: context.colors.sectionBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppSizes.sp28),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable small widgets ───────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppSizes.h48,
        height: AppSizes.h48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(icon, color: color, size: AppSizes.sp20),
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.isSending,
    required this.icon,
    required this.onTap,
  });

  final bool isSending;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onTap,
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
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.buttonText,
                ),
              )
            : Icon(icon, color: AppColors.buttonText, size: AppSizes.sp20),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: AppSizes.sp10,
        height: AppSizes.sp10,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  final String message;
  final VoidCallback onDismiss;

  /// When non-null, a "Retry" button is shown beside the dismiss icon.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph4,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw12,
        vertical: AppSizes.ph8,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.r12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: AppSizes.sp16,
          ),
          SizedBox(width: AppSizes.w8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontSize: AppSizes.sp12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(width: AppSizes.w8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: AppSizes.sp12,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          SizedBox(width: AppSizes.w6),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              color: AppColors.error,
              size: AppSizes.sp16,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Summary sheet ─────────────────────────────────────────────────────────

void _showSummarizeSheet(
  BuildContext context, {
  required List<ChatMessage> messages,
  required String messagesPath,
  required String chatTitle,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.cardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r20)),
    ),
    builder: (_) => _SummaryChatSheet(
      messages: messages,
      messagesPath: messagesPath,
      chatTitle: chatTitle,
    ),
  );
}

class _SummaryChatSheet extends StatefulWidget {
  const _SummaryChatSheet({
    required this.messages,
    required this.messagesPath,
    required this.chatTitle,
  });

  final List<ChatMessage> messages;
  final String messagesPath;
  final String chatTitle;

  @override
  State<_SummaryChatSheet> createState() => _SummaryChatSheetState();
}

class _SummaryChatSheetState extends State<_SummaryChatSheet> {
  ChatSummary? _summary;
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
      final existing =
          await AiSummaryService.instance.fetchSummary(widget.messagesPath);
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
    debugPrint('[AI_SUMMARY] summary button pressed — '
        '${widget.messages.length} messages in view');

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final langCode =
          context.read<LocaleProvider>().locale.languageCode;
      final result = await AiSummaryService.instance.summarize(
        messages: widget.messages,
        messagesPath: widget.messagesPath,
        chatTitle: widget.chatTitle,
        languageCode: langCode,
      );
      if (mounted) {
        setState(() {
          _summary = result;
          _generating = false;
        });
      }
    } catch (e) {
      debugPrint('[AI_SUMMARY] generate error: $e');
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
            // Header row
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
                    child: Text(
                      AppLocalizations.of(context)!.aiSummaryTitle,
                      style: GoogleFonts.manrope(
                        color: context.colors.textTitle,
                        fontWeight: FontWeight.w800,
                        fontSize: AppSizes.sp16,
                      ),
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
                            ? AppLocalizations.of(context)!.aiSummaryGenerate
                            : AppLocalizations.of(context)!.aiSummaryRegenerate,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp12,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.pw16,
                      ),
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
                                'Analysing conversation…',
                                style: GoogleFonts.manrope(
                                  color: context.colors.textMuted,
                                  fontSize: AppSizes.sp13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _summary == null
                          ? _SummaryEmptyState(onGenerate: _generate)
                          : _SummaryContent(
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

// ── Empty state ────────────────────────────────────────────────────────────────

class _SummaryEmptyState extends StatelessWidget {
  const _SummaryEmptyState({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.fileText,
              color: context.colors.textMuted,
              size: AppSizes.sp40,
            ),
            SizedBox(height: AppSizes.ph16),
            Text(
              AppLocalizations.of(context)!.aiSummaryEmptyTitle,
              style: GoogleFonts.manrope(
                color: context.colors.textTitle,
                fontWeight: FontWeight.w700,
                fontSize: AppSizes.sp14,
              ),
            ),
            SizedBox(height: AppSizes.ph8),
            Text(
              AppLocalizations.of(context)!.aiSummaryEmptySubtitle,
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
                  AppLocalizations.of(context)!.aiSummaryGenerateButton,
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

// ── Summary content ────────────────────────────────────────────────────────────

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.summary,
    required this.scrollController,
    this.error,
  });

  final ChatSummary summary;
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
        _SummarySection(
          icon: LucideIcons.messageSquare,
          title: AppLocalizations.of(context)!.aiSummaryMainPoints,
          body: summary.mainPoints,
        ),
        _SummarySection(
          icon: LucideIcons.checkCircle,
          title: AppLocalizations.of(context)!.aiSummaryDecisions,
          body: summary.importantDecisions,
        ),
        _SummarySection(
          icon: LucideIcons.clipboardList,
          title: AppLocalizations.of(context)!.aiSummaryTasks,
          body: summary.tasksAndActionItems,
        ),
        _SummarySection(
          icon: LucideIcons.clock,
          title: AppLocalizations.of(context)!.aiSummaryDeadlines,
          body: summary.deadlinesAndCommitments,
        ),
        _SummarySection(
          icon: LucideIcons.barChart2,
          title: AppLocalizations.of(context)!.aiSummaryTone,
          body: summary.overallTone,
        ),
        SizedBox(height: AppSizes.ph8),
        Text(
          AppLocalizations.of(context)!.aiSummaryGeneratedAt(
              _formatDate(summary.generatedAt)),
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

class _SummarySection extends StatelessWidget {
  const _SummarySection({
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

