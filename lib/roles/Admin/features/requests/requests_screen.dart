import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/access_request_model.dart';
import 'controller/request_controller.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RequestController(),
      child: const _RequestsView(),
    );
  }
}

class _RequestsView extends StatelessWidget {
  const _RequestsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RequestController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Access Requests',
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.pw24,
            vertical: AppSizes.ph20,
          ),
          child: _buildBody(context, controller),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, RequestController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(message: controller.errorMessage!);
    }

    if (controller.requests.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: controller.requests.length,
      separatorBuilder: (context, _) => SizedBox(height: AppSizes.ph16),
      itemBuilder: (context, index) {
        final request = controller.requests[index];
        return _RequestCard(
          request: request,
          isProcessing: controller.isProcessing(
            request.id ?? request.uid ?? request.email,
          ),
          onApprove: () => controller.approveRequest(context, request),
          onReject: () => controller.rejectRequest(context, request),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AccessRequestModel request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSizes.ph16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.r16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: AppSizes.h32,
            offset: Offset(0, AppSizes.h16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: AppSizes.h6),
                    Text(
                      request.department.isNotEmpty
                          ? request.department
                          : 'No department specified',
                      style: GoogleFonts.manrope(
                        color: AppColors.textSubtitle,
                        fontSize: AppSizes.sp12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.pw12,
                  vertical: AppSizes.ph6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.r12),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timelapse,
                      size: AppSizes.sp14,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: AppSizes.w6),
                    Text(
                      'PENDING',
                      style: GoogleFonts.manrope(
                        color: AppColors.primaryColor,
                        fontSize: AppSizes.sp12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.ph12),
          _InfoRow(icon: Icons.email_outlined, label: request.email),
          SizedBox(height: AppSizes.h8),
          _InfoRow(
            icon: Icons.account_tree_outlined,
            label: request.organizationName,
          ),
          SizedBox(height: AppSizes.h8),
          _InfoRow(icon: Icons.event, label: _formatDate(request.createdAt)),
          SizedBox(height: AppSizes.ph16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSizes.h44,
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.inputBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r12),
                      ),
                    ),
                    child: isProcessing
                        ? SizedBox(
                            height: AppSizes.h20,
                            width: AppSizes.h20,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : Text(
                            'Reject',
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(width: AppSizes.w12),
              Expanded(
                child: SizedBox(
                  height: AppSizes.h44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.r12),
                    ),
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                        ),
                      ),
                      child: isProcessing
                          ? SizedBox(
                              height: AppSizes.h20,
                              width: AppSizes.h20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.buttonText,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Accept',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.buttonText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: AppSizes.w8),
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.buttonText,
                                  size: AppSizes.sp18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Awaiting timestamp';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppSizes.w8),
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.circular(AppSizes.r10),
          ),
          child: Icon(icon, size: AppSizes.sp14, color: AppColors.textMuted),
        ),
        SizedBox(width: AppSizes.w12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textPrimary,
              fontSize: AppSizes.sp12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.ph20),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.circular(AppSizes.r20),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: AppSizes.h40,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          Text(
            'No pending requests',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            'New access requests will appear here.',
            style: GoogleFonts.manrope(
              color: AppColors.textSubtitle,
              fontSize: AppSizes.sp12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: AppSizes.h40, color: AppColors.error),
          SizedBox(height: AppSizes.ph12),
          Text(
            'Something went wrong',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textSubtitle,
                fontSize: AppSizes.sp12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
