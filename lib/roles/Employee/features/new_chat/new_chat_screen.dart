import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import '../chat/employee_chat_screen.dart';
import 'controller/new_chat_controller.dart';

class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key, required this.currentEmployee});

  final EmployeeModel currentEmployee;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewChatController(currentEmployee: currentEmployee),
      child: _NewChatView(currentEmployee: currentEmployee),
    );
  }
}

class _NewChatView extends StatelessWidget {
  const _NewChatView({required this.currentEmployee});

  final EmployeeModel currentEmployee;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NewChatController>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.newChatTitle,
          style: GoogleFonts.manrope(
            color: AppColors.textTitle,
            fontWeight: FontWeight.w800,
            fontSize: AppSizes.sp16,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(onChanged: controller.onSearchChanged),
            SizedBox(height: AppSizes.ph12),
            Expanded(
              child: _buildBody(context, controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NewChatController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(message: controller.errorMessage!);
    }

    if (controller.filteredEmployees.isEmpty) {
      return const _EmptyState();
    }

    return Stack(
      children: [
        _EmployeeList(
          employees: controller.filteredEmployees,
          onTap: (other) => _onEmployeeTap(context, controller, other),
        ),
        if (controller.isCreating)
          const _CreatingOverlay(),
      ],
    );
  }

  Future<void> _onEmployeeTap(
    BuildContext context,
    NewChatController controller,
    EmployeeModel other,
  ) async {
    final chatId = await controller.startPrivateChat(other);
    if (chatId == null) return;
    if (!context.mounted) return;

    final orgId = currentEmployee.organizationId;
    final messagesPath =
        'organizations/$orgId/private_chats/$chatId/messages';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeChatScreen(
          employee: currentEmployee,
          chatTitle: other.name,
          chatSubtitle: AppLocalizations.of(context)!.privateChatSubtitle,
          messagesPath: messagesPath,
          otherUid: other.id,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pw16,
        AppSizes.ph16,
        AppSizes.pw16,
        0,
      ),
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
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: AppColors.textMuted,
              size: AppSizes.sp20,
            ),
            SizedBox(width: AppSizes.w12),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontSize: AppSizes.sp14,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: AppLocalizations.of(context)!.searchByEmployeeId,
                  hintStyle: GoogleFonts.manrope(
                    color: AppColors.hintText,
                    fontSize: AppSizes.sp14,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({required this.employees, required this.onTap});

  final List<EmployeeModel> employees;
  final ValueChanged<EmployeeModel> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.pw16,
        vertical: AppSizes.ph4,
      ),
      itemCount: employees.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.inputBorder,
        height: 1,
        thickness: 1,
      ),
      itemBuilder: (context, index) {
        return _EmployeeTile(
          employee: employees[index],
          onTap: () => onTap(employees[index]),
        );
      },
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});

  final EmployeeModel employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.r12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.pw8,
          vertical: AppSizes.ph12,
        ),
        child: Row(
          children: [
            _Avatar(avatarUrl: employee.avatarUrl),
            SizedBox(width: AppSizes.w12),
            Expanded(
              child: Text(
                employee.name,
                style: GoogleFonts.manrope(
                  color: AppColors.textTitle,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.sp14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: AppSizes.sp20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl = ''});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.h48,
      width: AppSizes.w48,
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inputBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              placeholder: (_, url) => Icon(
                Icons.person_outline,
                color: AppColors.primaryColor,
                size: AppSizes.sp20,
              ),
              errorWidget: (_, url, error) => Icon(
                Icons.person_outline,
                color: AppColors.primaryColor,
                size: AppSizes.sp20,
              ),
            )
          : Icon(
              Icons.person_outline,
              color: AppColors.primaryColor,
              size: AppSizes.sp20,
            ),
    );
  }
}

class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x66000000),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      ),
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
          Icon(
            Icons.people_outline,
            color: AppColors.textMuted,
            size: AppSizes.sp40,
          ),
          SizedBox(height: AppSizes.h16),
          Text(
            AppLocalizations.of(context)!.noEmployeesFound,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.pw24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: AppSizes.sp40,
            ),
            SizedBox(height: AppSizes.h16),
            Text(
              AppLocalizations.of(context)!.somethingWentWrong,
              style: GoogleFonts.manrope(
                color: AppColors.textTitle,
                fontSize: AppSizes.sp16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSizes.h8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.textMuted,
                fontSize: AppSizes.sp12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}