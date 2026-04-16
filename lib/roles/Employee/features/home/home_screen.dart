import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/post_model.dart';
import 'controller/post_controller.dart';
import 'create_post_screen.dart';

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

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
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
                color: AppColors.textTitle,
                fontWeight: FontWeight.w800,
                fontSize: AppSizes.sp16,
              ),
            ),
            Text(
              'FEED',
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
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
            Expanded(child: _buildBody(context, controller)),
            _AddPostButton(employee: employee),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostController controller) {
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
                color: AppColors.textMuted,
                fontSize: AppSizes.sp14,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.posts.isEmpty) {
      return const _EmptyFeed();
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph12,
      ),
      itemCount: controller.posts.length,
      separatorBuilder: (_, _i) => SizedBox(height: AppSizes.h12),
      itemBuilder: (_, i) => PostCard(
        post: controller.posts[i],
        currentDisplayId: employee.displayId,
        onEdit: (post) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatePostScreen(
              employee: employee,
              existingPost: post,
            ),
          ),
        ),
        onDelete: (post) => _confirmDelete(context, controller, post),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PostController controller,
    PostModel post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.r16),
        ),
        title: Text(
          'Delete Post',
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
        content: Text(
          'This post will be permanently removed. This action cannot be undone.',
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
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
                'ADD POST',
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
//
// Layout:
//   ┌──────────────────────────────────────────┐
//   │ [Avatar]  Name               • 2h ago  ⋮ │  ← header (⋮ only for owner)
//   │           EMP-XXXXX                       │
//   ├──────────────────────────────────────────┤
//   │  Post text content...                     │  ← body
//   │                                           │
//   │  [media: full-width single / h-scroll]   │
//   ├──────────────────────────────────────────┤
//   │  ♡ 12 Likes    💬 5 Comments             │  ← footer
//   └──────────────────────────────────────────┘
//
// Ownership: the ⋮ menu is only shown when post.createdByDisplayId == currentDisplayId.

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentDisplayId,
    required this.onEdit,
    required this.onDelete,
  });

  final PostModel post;

  /// The display-ID of the currently logged-in employee.
  final String currentDisplayId;

  final ValueChanged<PostModel> onEdit;
  final ValueChanged<PostModel> onDelete;

  bool get _isOwner => post.createdByDisplayId == currentDisplayId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: AppColors.inputBorder),
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
                _PostAvatar(name: post.createdByName),
                SizedBox(width: AppSizes.w10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.createdByName,
                        style: GoogleFonts.manrope(
                          color: AppColors.textTitle,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.sp14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSizes.h2),
                      Text(
                        post.createdByDisplayId,
                        style: GoogleFonts.manrope(
                          color: AppColors.primaryColor,
                          fontSize: AppSizes.sp10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTime(post.createdAt),
                  style: GoogleFonts.manrope(
                    color: AppColors.textMuted,
                    fontSize: AppSizes.sp11,
                  ),
                ),
                // ── Owner actions menu ──
                if (_isOwner)
                  _PostActionsMenu(
                    onEdit: () => onEdit(post),
                    onDelete: () => onDelete(post),
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
                  color: AppColors.textPrimary,
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
                const Divider(
                  color: AppColors.inputBorder,
                  height: 1,
                  thickness: 1,
                ),
                SizedBox(height: AppSizes.h10),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.favorite_border_rounded,
                      count: post.likes,
                      label: 'Likes',
                    ),
                    SizedBox(width: AppSizes.w16),
                    _StatChip(
                      icon: Icons.chat_bubble_outline_rounded,
                      count: post.commentsCount,
                      label: 'Comments',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Owner actions menu (⋮) ───────────────────────────────────────────────────

class _PostActionsMenu extends StatelessWidget {
  const _PostActionsMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PostAction>(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.textMuted,
        size: AppSizes.sp20,
      ),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r12),
        side: const BorderSide(color: AppColors.inputBorder),
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
                'Edit',
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
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
                'Delete',
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
  const _PostAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
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
//
// Single image  → full-width, fixed height 240.
// 2–4 images    → horizontal scroll, each tile 200×200.

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

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: AppSizes.sp16),
        SizedBox(width: AppSizes.w6),
        Text(
          '$count $label',
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: AppSizes.sp12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Empty feed ───────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, color: AppColors.textMuted, size: AppSizes.sp40),
          SizedBox(height: AppSizes.h16),
          Text(
            'No posts yet',
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            'Be the first to share something.',
            style: GoogleFonts.manrope(
              color: AppColors.navUnselected,
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
        baseColor: AppColors.cardBackground,
        highlightColor: AppColors.sectionBackground,
        child: Container(
          height: AppSizes.h140,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.r16),
          ),
        ),
      ),
    );
  }
}
