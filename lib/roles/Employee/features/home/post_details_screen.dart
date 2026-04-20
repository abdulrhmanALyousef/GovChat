import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/comment_model.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/post_model.dart';
import 'controller/post_details_controller.dart';

class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({
    super.key,
    required this.post,
    required this.employee,
  });

  final PostModel post;
  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PostDetailsController(
        employeeId: post.employeeId,
        postId: post.id!,
      ),
      child: _PostDetailsView(employee: employee, initialPost: post),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _PostDetailsView extends StatelessWidget {
  const _PostDetailsView({
    required this.employee,
    required this.initialPost,
  });

  final EmployeeModel employee;
  final PostModel initialPost;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostDetailsController>();
    final post = controller.post ?? initialPost;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textTitle),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.postTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: controller.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  )
                : controller.errorMessage != null
                    ? Center(
                        child: Text(
                          controller.errorMessage!,
                          style: GoogleFonts.manrope(
                            color: AppColors.textMuted,
                            fontSize: AppSizes.sp14,
                          ),
                        ),
                      )
                    : _buildContent(context, controller, post, l),
          ),
          _CommentInputBar(
            employee: employee,
            controller: controller,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PostDetailsController controller,
    PostModel post,
    AppLocalizations l,
  ) {
    final isLiked = post.likedBy.contains(employee.displayId);

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph16,
      ),
      children: [
        // ── Post card ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r16),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pw16,
                  AppSizes.ph14,
                  AppSizes.pw16,
                  0,
                ),
                child: Row(
                  children: [
                    _Avatar(displayId: post.createdByDisplayId),
                    SizedBox(width: AppSizes.w10),
                    Expanded(
                      child: Text(
                        post.createdByDisplayId,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp14,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt, l),
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: AppSizes.sp11,
                      ),
                    ),
                  ],
                ),
              ),

              // Text
              if (post.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.pw16,
                    AppSizes.ph12,
                    AppSizes.pw16,
                    0,
                  ),
                  child: Text(
                    post.text,
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontSize: AppSizes.sp14,
                      height: 1.55,
                    ),
                  ),
                ),

              // Media
              if (post.mediaUrls.isNotEmpty) ...[
                SizedBox(height: AppSizes.h12),
                _MediaRow(urls: post.mediaUrls),
              ],

              // Likes row
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pw16,
                  AppSizes.ph12,
                  AppSizes.pw16,
                  AppSizes.ph14,
                ),
                child: Column(
                  children: [
                    const Divider(
                      color: AppColors.inputBorder,
                      height: 1,
                      thickness: 1,
                    ),
                    SizedBox(height: AppSizes.h10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              controller.toggleLike(employee.displayId),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isLiked
                                    ? AppColors.error
                                    : AppColors.textMuted,
                                size: AppSizes.sp18,
                              ),
                              SizedBox(width: AppSizes.w6),
                              Text(
                                '${post.likes} ${post.likes == 1 ? l.likeSingular : l.likePlural}',
                                style: GoogleFonts.manrope(
                                  color: isLiked
                                      ? AppColors.error
                                      : AppColors.textMuted,
                                  fontSize: AppSizes.sp12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSizes.w16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.textMuted,
                              size: AppSizes.sp16,
                            ),
                            SizedBox(width: AppSizes.w6),
                            Text(
                              '${post.commentsCount} ${post.commentsCount == 1 ? l.commentSingular : l.commentPlural}',
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted,
                                fontSize: AppSizes.sp12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: AppSizes.h20),

        // ── Comments section ──
        Text(
          l.commentPlural,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp14,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: AppSizes.h12),

        if (controller.comments.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.ph20),
            child: Center(
              child: Text(
                l.noCommentsYet,
                style: GoogleFonts.manrope(
                  color: AppColors.textMuted,
                  fontSize: AppSizes.sp13,
                ),
              ),
            ),
          )
        else
          ...controller.comments.map(
            (c) => Padding(
              padding: EdgeInsets.only(bottom: AppSizes.ph8),
              child: _CommentTile(comment: c),
            ),
          ),

        SizedBox(height: AppSizes.ph8),
      ],
    );
  }

  String _formatTime(DateTime? dt, AppLocalizations l) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l.justNow;
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Comment tile ─────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(AppSizes.pw12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(displayId: comment.createdByDisplayId, size: 34),
          SizedBox(width: AppSizes.w10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.createdByDisplayId,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp13,
                          letterSpacing: 0.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(comment.createdAt, l),
                      style: GoogleFonts.manrope(
                        color: AppColors.textMuted,
                        fontSize: AppSizes.sp10,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.h6),
                Text(
                  comment.text,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.sp13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt, AppLocalizations l) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return l.justNow;
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Comment input bar ────────────────────────────────────────────────────────

class _CommentInputBar extends StatefulWidget {
  const _CommentInputBar({
    required this.employee,
    required this.controller,
  });

  final EmployeeModel employee;
  final PostDetailsController controller;

  @override
  State<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<_CommentInputBar> {
  final _textController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final has = _textController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _hasText = false);
    await widget.controller.addComment(
      text: text,
      createdByDisplayId: widget.employee.displayId,
      createdByName: widget.employee.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = widget.controller.isSubmitting;
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        AppSizes.ph12,
        AppSizes.pw16,
        AppSizes.ph16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.inputBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(AppSizes.r24),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _textController,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontSize: AppSizes.sp14,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l.writeACommentHint,
                  hintStyle: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp14,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSizes.pw16,
                    vertical: AppSizes.ph8,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSizes.w10),
          GestureDetector(
            onTap: (!_hasText || submitting) ? null : _submit,
            child: Container(
              width: AppSizes.w42,
              height: AppSizes.h42,
              decoration: BoxDecoration(
                gradient: (!_hasText || submitting)
                    ? null
                    : const LinearGradient(
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                color: (!_hasText || submitting)
                    ? AppColors.sectionBackground
                    : null,
                shape: BoxShape.circle,
              ),
              child: submitting
                  ? Center(
                      child: SizedBox(
                        width: AppSizes.w16,
                        height: AppSizes.h16,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: _hasText
                          ? AppColors.buttonText
                          : AppColors.textMuted,
                      size: AppSizes.sp18,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared avatar ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.displayId, this.size = 42});

  final String displayId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = displayId.isNotEmpty ? displayId[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.manrope(
            color: AppColors.primaryColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

// ─── Media row ────────────────────────────────────────────────────────────────

class _MediaRow extends StatelessWidget {
  const _MediaRow({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          child: CachedNetworkImage(
            imageUrl: urls.first,
            width: double.infinity,
            height: AppSizes.h240,
            fit: BoxFit.cover,
            placeholder: (_, _a) => _shimmerBox(double.infinity, AppSizes.h240),
            errorWidget: (_, _a, _b) => _errorBox(double.infinity, AppSizes.h240),
          ),
        ),
      );
    }

    return SizedBox(
      height: AppSizes.h200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw16),
        itemCount: urls.length,
        separatorBuilder: (_, _i) => SizedBox(width: AppSizes.w8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            width: AppSizes.w200,
            height: AppSizes.h200,
            fit: BoxFit.cover,
            placeholder: (_, _a) => _shimmerBox(AppSizes.w200, AppSizes.h200),
            errorWidget: (_, _a, _b) => _errorBox(AppSizes.w200, AppSizes.h200),
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h) {
    return Shimmer.fromColors(
      baseColor: AppColors.sectionBackground,
      highlightColor: AppColors.cardBackground,
      child: Container(width: w, height: h, color: AppColors.sectionBackground),
    );
  }

  Widget _errorBox(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: AppColors.sectionBackground,
      child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
    );
  }
}