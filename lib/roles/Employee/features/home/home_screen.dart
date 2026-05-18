import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/post_model.dart';
import 'controller/post_controller.dart';
import 'create_post_screen.dart';
import 'post_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PostController(),
      child: _HomeView(employee: employee),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  const _HomeView({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: context.colors.cardBackground,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: AppSizes.pw16),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryColor,
          ),
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
              l.feedLabel,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp10,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(context, controller, l)),
            _AddPostButton(employee: employee),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostController controller, AppLocalizations l) {
    if (controller.isLoading) {
      return ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw16,
          vertical: AppSizes.ph12,
        ),
        itemCount: 4,
        itemBuilder: (_, _i) => _PostCardShimmer(),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: AppSizes.sp40),
            SizedBox(height: AppSizes.h12),
            Text(
              controller.errorMessage!,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontSize: AppSizes.sp14,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.posts.isEmpty) {
      return _EmptyFeed();
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph12,
      ),
      itemCount: controller.posts.length,
      separatorBuilder: (_, _i) => SizedBox(height: AppSizes.h12),
      itemBuilder: (_, i) {
        final post = controller.posts[i];
        return PostCard(
          post: post,
          currentDisplayId: employee.displayId,
          onEdit: (p) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePostScreen(
                employee: employee,
                existingPost: p,
              ),
            ),
          ),
          onDelete: (p) => _confirmDelete(context, controller, p, l),
          onLike: (p) => controller.toggleLike(p, employee.displayId),
          onTap: (p) {
            if (p.id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsScreen(
                  post: p,
                  employee: employee,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PostController controller,
    PostModel post,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.r16),
        ),
        title: Text(
          l.deletePostTitle,
          style: GoogleFonts.manrope(
            color: context.colors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
        content: Text(
          l.deletePostConfirm,
          style: GoogleFonts.manrope(
            color: context.colors.textMuted,
            fontSize: AppSizes.sp13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l.cancelButton,
              style: GoogleFonts.manrope(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.deleteButton,
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deletePost(post);
    }
  }
}

// ─── Add Post button ──────────────────────────────────────────────────────────

class _AddPostButton extends StatelessWidget {
  const _AddPostButton({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        AppSizes.ph12,
        AppSizes.pw16,
        AppSizes.ph16,
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(employee: employee),
          ),
        ),
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
                l.addPostButton,
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

// ─── Post card ────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentDisplayId,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
    required this.onTap,
  });

  final PostModel post;
  final String currentDisplayId;
  final ValueChanged<PostModel> onEdit;
  final ValueChanged<PostModel> onDelete;
  final ValueChanged<PostModel> onLike;
  final ValueChanged<PostModel> onTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;

  late bool _optimisticLiked;
  late int _likesDelta;

  bool get _isOwner =>
      widget.post.createdByDisplayId == widget.currentDisplayId;

  @override
  void initState() {
    super.initState();
    _optimisticLiked =
        widget.post.likedBy.contains(widget.currentDisplayId);
    _likesDelta = 0;

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_heartController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartController);
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) {
      _optimisticLiked =
          widget.post.likedBy.contains(widget.currentDisplayId);
      _likesDelta = 0;
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleLike() {
    setState(() {
      _optimisticLiked = !_optimisticLiked;
      _likesDelta += _optimisticLiked ? 1 : -1;
    });
    widget.onLike(widget.post);
  }

  void _handleDoubleTap() {
    _heartController
      ..reset()
      ..forward();
    _handleLike();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayedLikes = post.likes + _likesDelta;
    final l = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => widget.onTap(post),
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Card ──
          Container(
            decoration: BoxDecoration(
              color: context.colors.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.r16),
              border: Border.all(color: context.colors.inputBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.pw16,
                    AppSizes.ph14,
                    AppSizes.pw8,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PostAvatar(
                        displayId: post.createdByDisplayId,
                        employeeId: post.employeeId,
                      ),
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
                          color: context.colors.textMuted,
                          fontSize: AppSizes.sp11,
                        ),
                      ),
                      if (_isOwner)
                        _PostActionsMenu(
                          onEdit: () => widget.onEdit(post),
                          onDelete: () => widget.onDelete(post),
                          l: l,
                        ),
                      if (!_isOwner) SizedBox(width: AppSizes.pw8),
                    ],
                  ),
                ),

                // ── Text ──
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
                        color: context.colors.textPrimary,
                        fontSize: AppSizes.sp14,
                        height: 1.55,
                      ),
                    ),
                  ),

                // ── Media ──
                if (post.mediaUrls.isNotEmpty) ...[
                  SizedBox(height: AppSizes.h12),
                  _MediaRow(urls: post.mediaUrls),
                ],

                // ── Footer ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.pw16,
                    AppSizes.ph12,
                    AppSizes.pw16,
                    AppSizes.ph14,
                  ),
                  child: Column(
                    children: [
                      Divider(
                        color: context.colors.inputBorder,
                        height: 1,
                        thickness: 1,
                      ),
                      SizedBox(height: AppSizes.h10),
                      Row(
                        children: [
                          // Like button
                          GestureDetector(
                            onTap: _handleLike,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _optimisticLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: _optimisticLiked
                                      ? AppColors.error
                                      : context.colors.textMuted,
                                  size: AppSizes.sp16,
                                ),
                                SizedBox(width: AppSizes.w6),
                                Text(
                                  '$displayedLikes ${displayedLikes == 1 ? l.likeSingular : l.likePlural}',
                                  style: GoogleFonts.manrope(
                                    color: _optimisticLiked
                                        ? AppColors.error
                                        : context.colors.textMuted,
                                    fontSize: AppSizes.sp12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: AppSizes.w16),
                          // Comments chip
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: context.colors.textMuted,
                                size: AppSizes.sp16,
                              ),
                              SizedBox(width: AppSizes.w6),
                              Text(
                                '${post.commentsCount} ${post.commentsCount == 1 ? l.commentSingular : l.commentPlural}',
                                style: GoogleFonts.manrope(
                                  color: context.colors.textMuted,
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

          // ── Floating heart animation ──
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (_, _a) {
                if (_heartController.status == AnimationStatus.dismissed) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _heartOpacity.value,
                  child: Transform.scale(
                    scale: _heartScale.value,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: AppColors.error,
                      size: AppSizes.sp64,
                    ),
                  ),
                );
              },
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

// ─── Owner actions menu (⋮) ───────────────────────────────────────────────────

class _PostActionsMenu extends StatelessWidget {
  const _PostActionsMenu({
    required this.onEdit,
    required this.onDelete,
    required this.l,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PostAction>(
      icon: Icon(
        Icons.more_vert,
        color: context.colors.textMuted,
        size: AppSizes.sp20,
      ),
      color: context.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r12),
        side: BorderSide(color: context.colors.inputBorder),
      ),
      onSelected: (action) {
        if (action == _PostAction.edit) onEdit();
        if (action == _PostAction.delete) onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _PostAction.edit,
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: AppColors.primaryColor,
                size: AppSizes.sp16,
              ),
              SizedBox(width: AppSizes.w10),
              Text(
                l.editMenuItem,
                style: GoogleFonts.manrope(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.sp13,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PostAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: AppSizes.sp16,
              ),
              SizedBox(width: AppSizes.w10),
              Text(
                l.deleteMenuItem,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.sp13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _PostAction { edit, delete }

// ─── Post avatar ──────────────────────────────────────────────────────────────

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({required this.displayId, required this.employeeId});

  final String displayId;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final initial = displayId.isNotEmpty ? displayId[0].toUpperCase() : '?';

    if (employeeId.isEmpty) {
      return _buildFallback(initial);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        final avatarUrl =
            snapshot.data?.data()?['avatarUrl'] as String? ?? '';

        return Container(
          width: AppSizes.w42,
          height: AppSizes.h42,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.35),
            ),
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
                        fontWeight: FontWeight.w800,
                        fontSize: AppSizes.sp16,
                      ),
                    ),
                  ),
                  errorWidget: (_, url, error) => Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.manrope(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: AppSizes.sp16,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.manrope(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: AppSizes.sp16,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildFallback(String initial) {
    return Container(
      width: AppSizes.w42,
      height: AppSizes.h42,
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
            fontSize: AppSizes.sp16,
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
            placeholder: (_, _a) => _shimmerBox(context, double.infinity, AppSizes.h240),
            errorWidget: (_, _a, _b) => _errorBox(context, double.infinity, AppSizes.h240),
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
            placeholder: (_, _a) => _shimmerBox(context, AppSizes.w200, AppSizes.h200),
            errorWidget: (_, _a, _b) => _errorBox(context, AppSizes.w200, AppSizes.h200),
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox(BuildContext context, double w, double h) {
    return Shimmer.fromColors(
      baseColor: context.colors.sectionBackground,
      highlightColor: context.colors.cardBackground,
      child: Container(width: w, height: h, color: context.colors.sectionBackground),
    );
  }

  Widget _errorBox(BuildContext context, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: context.colors.sectionBackground,
      child: Icon(Icons.broken_image_outlined, color: context.colors.textMuted),
    );
  }
}

// ─── Empty feed ───────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, color: context.colors.textMuted, size: AppSizes.sp40),
          SizedBox(height: AppSizes.h16),
          Text(
            l.noPostsYet,
            style: GoogleFonts.manrope(
              color: context.colors.textMuted,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            l.beFirstToShare,
            style: GoogleFonts.manrope(
              color: context.colors.navUnselected,
              fontSize: AppSizes.sp13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer placeholder card ─────────────────────────────────────────────────

class _PostCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.h12),
      child: Shimmer.fromColors(
        baseColor: context.colors.cardBackground,
        highlightColor: context.colors.sectionBackground,
        child: Container(
          height: AppSizes.h140,
          decoration: BoxDecoration(
            color: context.colors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r16),
          ),
        ),
      ),
    );
  }
}