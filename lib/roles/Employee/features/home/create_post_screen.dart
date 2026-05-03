import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../../../../models/post_model.dart';
import 'controller/create_post_controller.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({
    super.key,
    required this.employee,
    this.existingPost,
  });

  final EmployeeModel employee;

  /// Pass a [PostModel] to open the screen in edit mode.
  final PostModel? existingPost;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreatePostController(
        employee: employee,
        existingPost: existingPost,
      ),
      child: const _CreatePostView(),
    );
  }
}

// ─── Main view ────────────────────────────────────────────────────────────────

class _CreatePostView extends StatelessWidget {
  const _CreatePostView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CreatePostController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          controller.isEditMode ? l.editPostTitle : l.newPostTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: AppSizes.pw16),
            child: _PostButton(controller: controller),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSizes.pw16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Author row ──
                    Row(
                      children: [
                        _AuthorAvatar(
                          name: controller.employee.name,
                          avatarUrl: controller.employee.avatarUrl,
                        ),
                        SizedBox(width: AppSizes.w12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.employee.name,
                              style: GoogleFonts.manrope(
                                color: AppColors.textTitle,
                                fontWeight: FontWeight.w700,
                                fontSize: AppSizes.sp14,
                              ),
                            ),
                            Text(
                              controller.employee.displayId,
                              style: GoogleFonts.manrope(
                                color: AppColors.textMuted,
                                fontSize: AppSizes.sp11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: AppSizes.h16),

                    // ── Text field ──
                    TextField(
                      controller: controller.textController,
                      onChanged: (_) =>
                          context.read<CreatePostController>().onTextChanged(),
                      maxLines: null,
                      minLines: 4,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontSize: AppSizes.sp14,
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: l.whatsOnYourMind,
                        hintStyle: GoogleFonts.manrope(
                          color: AppColors.hintText,
                          fontSize: AppSizes.sp14,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),

                    // ── Media preview ──
                    if (controller.totalMediaCount > 0) ...[
                      SizedBox(height: AppSizes.h16),
                      _MediaPreviewGrid(controller: controller),
                    ],

                    // ── Error ──
                    if (controller.errorMessage != null) ...[
                      SizedBox(height: AppSizes.h16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppSizes.ph12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.r8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          controller.errorMessage!,
                          style: GoogleFonts.manrope(
                            color: AppColors.error,
                            fontSize: AppSizes.sp12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom toolbar ──
            _BottomToolbar(controller: controller),
          ],
        ),
      ),
    );
  }
}

// ─── POST button ──────────────────────────────────────────────────────────────

class _PostButton extends StatelessWidget {
  const _PostButton({required this.controller});

  final CreatePostController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: controller.canPost
          ? () async {
              final success = await controller.submitPost();
              if (success && context.mounted) Navigator.pop(context);
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw16,
          vertical: AppSizes.ph6,
        ),
        decoration: BoxDecoration(
          gradient: controller.canPost
              ? const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                )
              : null,
          color: controller.canPost ? null : AppColors.inputBorder,
          borderRadius: BorderRadius.circular(AppSizes.r20),
        ),
        child: controller.isPosting
            ? SizedBox(
                width: AppSizes.w16,
                height: AppSizes.h16,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.buttonText,
                ),
              )
            : Text(
                controller.isEditMode ? l.savePostButton : l.postButton,
                style: GoogleFonts.manrope(
                  color: controller.canPost
                      ? AppColors.buttonText
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: AppSizes.sp13,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }
}

// ─── Author avatar ────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.name, this.avatarUrl = ''});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: AppSizes.w42,
      height: AppSizes.h42,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.4),
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
  }
}

// ─── Media preview grid ───────────────────────────────────────────────────────

class _MediaPreviewGrid extends StatelessWidget {
  const _MediaPreviewGrid({required this.controller});

  final CreatePostController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ── Kept remote images ──
        for (int i = 0; i < controller.keptMediaUrls.length; i++)
          _Thumbnail(
            child: CachedNetworkImage(
              imageUrl: controller.keptMediaUrls[i],
              width: AppSizes.w90,
              height: AppSizes.h90,
              fit: BoxFit.cover,
            ),
            onRemove: () => controller.removeKeptMedia(i),
          ),

        // ── Newly picked local images ──
        for (int i = 0; i < controller.pickedImages.length; i++)
          _Thumbnail(
            child: Image.file(
              File(controller.pickedImages[i].path),
              width: AppSizes.w90,
              height: AppSizes.h90,
              fit: BoxFit.cover,
            ),
            onRemove: () => controller.removeNewImage(i),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.r12),
          child: child,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom toolbar ───────────────────────────────────────────────────────────

class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({required this.controller});

  final CreatePostController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final atLimit = controller.totalMediaCount >= 4;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Row(
        children: [
          Text(
            l.addToPostLabel,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontSize: AppSizes.sp11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: AppSizes.w16),
          GestureDetector(
            onTap: atLimit ? null : controller.pickImages,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.pw12,
                vertical: AppSizes.ph8,
              ),
              decoration: BoxDecoration(
                color: AppColors.sectionBackground,
                borderRadius: BorderRadius.circular(AppSizes.r8),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: atLimit
                        ? AppColors.navUnselected
                        : AppColors.primaryColor,
                    size: AppSizes.sp18,
                  ),
                  SizedBox(width: AppSizes.w6),
                  Text(
                    l.photoCountLabel(controller.totalMediaCount),
                    style: GoogleFonts.manrope(
                      color: atLimit
                          ? AppColors.navUnselected
                          : AppColors.textPrimary,
                      fontSize: AppSizes.sp12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}