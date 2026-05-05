import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:projects/l10n/app_localizations.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/chat_message.dart';
import '../../../../models/unified_group.dart';

class AdminGroupChatScreen extends StatefulWidget {
  const AdminGroupChatScreen({super.key, required this.group});
  final UnifiedGroup group;

  @override
  State<AdminGroupChatScreen> createState() => _AdminGroupChatScreenState();
}

class _AdminGroupChatScreenState extends State<AdminGroupChatScreen> {
  final _firebase = FirebaseService.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ChatMessage> _messages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String _adminUid = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadAdminUid();
    _listenMessages();
  }

  Future<void> _loadAdminUid() async {
    final user = _firebase.currentUser;
    if (user == null) return;
    setState(() => _adminUid = user.uid);
  }

  void _listenMessages() {
    _sub = _firebase.firestore
        .collection(widget.group.messagesPath)
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
      setState(() {
        _messages = snap.docs
            .map((d) => ChatMessage.fromJson(d.data(), id: d.id))
            .where((m) => !m.isDeleted)
            .toList();
      });
      _scrollToBottom();
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    try {
      await _firebase.firestore.collection(widget.group.messagesPath).add({
        'text': text,
        'senderId': _adminUid,
        'senderRole': 'admin',
        'organizationId': _orgId,
        'departmentId': '',
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });

      LoggingService.instance.log(
        organizationId: _orgId,
        actionType: 'group_message_sent',
        descriptionKey: 'logGroupMessageSent',
        performedByUserId: _adminUid,
        performedByRole: 'admin',
        performedByEmail: _firebase.currentUser?.email ?? '',
        metadata: {
          'groupId': widget.group.id,
          'groupName': widget.group.name,
          'groupType': widget.group.type,
        },
      ).ignore();

      _scrollToBottom();
    } catch (_) {}

    if (mounted) setState(() => _isSending = false);
  }

  String get _orgId {
    final path = widget.group.messagesPath;
    if (path.startsWith('organizations/')) {
      final parts = path.split('/');
      if (parts.length > 1) return parts[1];
    }
    return '';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp16,
              ),
            ),
            Text(
              l.membersCount(widget.group.memberCount),
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontSize: AppSizes.sp10,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: AppSizes.ph4),
            color: AppColors.cardBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    color: AppColors.primaryColor, size: 12),
                SizedBox(width: AppSizes.w6),
                Text(
                  l.endToEndEncryptedChannel,
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontSize: AppSizes.sp9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      l.noMessagesYet,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: AppSizes.sp14,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.pw16,
                      vertical: AppSizes.ph8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderId == _adminUid;
                      return _MessageBubble(
                          msg: msg, isMe: isMe, adminLabel: l.adminLabel);
                    },
                  ),
          ),
          _InputBar(
            controller: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
            l: l,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.adminLabel,
  });
  final ChatMessage msg;
  final bool isMe;
  final String adminLabel;

  @override
  Widget build(BuildContext context) {
    final isAdmin = msg.senderRole == 'admin';
    final senderName = isAdmin ? adminLabel : msg.senderId;
    final senderColor =
        isAdmin ? const Color(0xFFEF4444) : AppColors.primaryColor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSizes.h8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw16,
          vertical: AppSizes.ph8,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primaryColor.withValues(alpha: 0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSizes.r16),
          border: Border.all(
            color: isMe
                ? AppColors.primaryColor.withValues(alpha: 0.3)
                : AppColors.inputBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                senderName,
                style: GoogleFonts.manrope(
                  color: senderColor,
                  fontSize: AppSizes.sp10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSizes.h4),
            ],
            Text(
              msg.text,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontSize: AppSizes.sp14,
              ),
            ),
            if (msg.createdAt != null) ...[
              SizedBox(height: AppSizes.h4),
              Text(
                _formatTime(msg.createdAt!),
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.l,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph8,
      ).copyWith(bottom: AppSizes.ph8 + MediaQuery.of(context).padding.bottom),
      color: AppColors.cardBackground,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.manrope(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: l.typeAMessage,
                hintStyle: GoogleFonts.manrope(color: AppColors.hintText),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSizes.pw16,
                  vertical: AppSizes.ph12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                  borderSide:
                      const BorderSide(color: AppColors.inputFocusBorder),
                ),
              ),
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
            ),
          ),
          SizedBox(width: AppSizes.w8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              padding: EdgeInsets.all(AppSizes.ph12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(AppSizes.r24),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.scaffoldBackground,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppColors.scaffoldBackground,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
