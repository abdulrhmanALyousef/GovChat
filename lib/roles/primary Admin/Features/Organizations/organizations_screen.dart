import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_color.dart';
import '../../../../core/Widgets/custom_text_form_field.dart';
import '../../../../core/Widgets/custom_dropdown_field.dart';
import 'controllers/organizarions_conttroller.dart';

class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrganizationsController(),
      child: const _OrganizationsView(),
    );
  }
}

class _OrganizationsView extends StatelessWidget {
  const _OrganizationsView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrganizationsController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Show success or error messages
    _showMessages(context, controller);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: controller.formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ──
                Text(
                  'Create Organization',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set up a new organization within the secure infrastructure.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Section: Organization Information ──
                _buildSectionTitle(context, 'ORGANIZATION INFORMATION'),
                const SizedBox(height: 16),

                // CustomTextFormField
                CustomTextFormField(
                  controller: controller.organizationNameController,
                  title: 'Organization Name',
                  hintText: 'Enter organization name',
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                CustomDropdownField(
                  title: 'City',
                  hintText: 'Select city',
                  value: controller.selectedCity,
                  items: controller.cities,
                  onChanged: controller.setCity,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                CustomTextFormField(
                  controller: controller.addressController,
                  title: 'Address (optional)',
                  hintText: 'Enter address',
                  maxLines: 3,
                ),
                const SizedBox(height: 28),

                // ── Section: Organization Details ──
                _buildSectionTitle(context, 'ORGANIZATION DETAILS'),
                const SizedBox(height: 16),

                // CustomDropdownField
                CustomDropdownField(
                  title: 'Industry (optional)',
                  hintText: 'Select industry',
                  value: controller.selectedIndustry,
                  items: controller.industries,
                  onChanged: controller.setIndustry,
                ),
                const SizedBox(height: 16),

                CustomDropdownField(
                  title: 'Number of Employees (optional)',
                  hintText: 'Select range',
                  value: controller.selectedEmployeeRange,
                  items: controller.employeeRanges,
                  onChanged: controller.setEmployeeRange,
                ),
                const SizedBox(height: 28),

                // ── Section: Admin Account ──
                _buildSectionTitle(context, 'ADMIN ACCOUNT'),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.dividerTheme.color ?? colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextFormField(
                        controller: controller.adminEmailController,
                        title: 'Admin Email',
                        hintText: 'Enter admin email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A temporary password will be generated and sent to the admin email. The admin will be required to change it on first login.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : controller.createOrganization,
                    child: controller.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'CREATE ORGANIZATION',
                            style: TextStyle(
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessages(BuildContext context, OrganizationsController controller) {
    if (controller.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.successMessage!),
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
        controller.clearMessages();
      });
    }

    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        controller.clearMessages();
      });
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(width: 3, height: 28, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textTitle,
            height: 28 / 18,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}
