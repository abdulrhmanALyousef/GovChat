import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_size.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../models/employee_model.dart';
import 'controller/employees_controller.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmployeesController(),
      child: const _EmployeesView(),
    );
  }
}

class _EmployeesView extends StatelessWidget {
  const _EmployeesView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EmployeesController>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Employees',
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
          child: _buildBody(controller),
        ),
      ),
    );
  }

  Widget _buildBody(EmployeesController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (controller.errorMessage != null) {
      return _ErrorState(message: controller.errorMessage!);
    }

    if (controller.employees.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: controller.employees.length,
      separatorBuilder: (context, _) => SizedBox(height: AppSizes.ph16),
      itemBuilder: (context, index) {
        final employee = controller.employees[index];
        return _EmployeeCard(employee: employee);
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee});

  final EmployeeModel employee;

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
                      employee.displayId.isNotEmpty
                          ? employee.displayId
                          : 'EMP-ID MISSING',
                      style: GoogleFonts.manrope(
                        color: AppColors.textTitle,
                        fontSize: AppSizes.sp18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: AppSizes.h6),
                    Text(
                      employee.department,
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
                      Icons.verified_outlined,
                      size: AppSizes.sp14,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: AppSizes.w6),
                    Text(
                      'ACTIVE',
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
          _InfoRow(icon: Icons.person_outline, label: employee.fullName),
          SizedBox(height: AppSizes.h8),
          _InfoRow(icon: Icons.email_outlined, label: employee.email),
          SizedBox(height: AppSizes.h8),
          _InfoRow(
            icon: Icons.apartment_outlined,
            label: employee.organizationName,
          ),
        ],
      ),
    );
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
              Icons.people_outline,
              size: AppSizes.h40,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: AppSizes.ph16),
          Text(
            'No employees yet',
            style: GoogleFonts.manrope(
              color: AppColors.textTitle,
              fontSize: AppSizes.sp16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSizes.h8),
          Text(
            'Approved employees will appear here.',
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
