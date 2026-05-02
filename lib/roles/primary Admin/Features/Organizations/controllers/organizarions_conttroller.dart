import 'package:flutter/material.dart';
import '../../../../../core/datasource/remote_data/firebase_service.dart';
import '../../../../../core/services/activity_log_service.dart';

class OrganizationsController extends ChangeNotifier {
  final TextEditingController organizationNameController =
      TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController adminEmailController = TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  String? selectedCity;
  String? selectedIndustry;
  String? selectedEmployeeRange;
  bool isLoading = false;
  String? successMessage;
  String? errorMessage;

  final List<String> industries = [
    'Technology',
    'Healthcare',
    'Finance',
    'Education',
    'Retail',
    'Manufacturing',
    'Other',
  ];

  final List<String> employeeRanges = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '500+',
  ];

  final List<String> cities = [
    'Riyadh',
    'Jeddah',
    'Mecca',
    'Medina',
    'Dammam',
    'Khobar',
    'Dhahran',
    'Tabuk',
    'Abha',
    'Taif',
    'Hail',
    'Jubail',
    'Yanbu',
    'Najran',
    'Jazan',
    'Al Baha',
    'Sakaka',
    'Arar',
    'Buraydah',
    'Unaizah',
    'Khamis Mushait',
    'Al Ahsa',
    'Al Qatif',
  ];

  void setCity(String? value) {
    selectedCity = value;
    notifyListeners();
  }

  void setIndustry(String? value) {
    selectedIndustry = value;
    notifyListeners();
  }

  void setEmployeeRange(String? value) {
    selectedEmployeeRange = value;
    notifyListeners();
  }

  Future<void> createOrganization() async {
    if (!formKey.currentState!.validate()) return;

    isLoading = true;
    successMessage = null;
    errorMessage = null;
    notifyListeners();

    final firebase = FirebaseService.instance;
    final email = adminEmailController.text.trim();
    final orgName = organizationNameController.text.trim();

    try {
      // Check if organization name already exists
      final nameTaken = await firebase.isOrganizationNameTaken(orgName);
      if (nameTaken) {
        errorMessage = 'Organization name "$orgName" already exists. Please choose a different name.';
        isLoading = false;
        notifyListeners();
        return;
      }

      final result = await firebase.createOrganizationWithAdmin(
        email: email,
        organizationName: orgName,
        city: selectedCity ?? '',
        address: addressController.text.trim(),
        industry: selectedIndustry,
        employeeRange: selectedEmployeeRange,
      );

      if (result['success'] != true) {
        errorMessage = result['error'];
        isLoading = false;
        notifyListeners();
        return;
      }

      successMessage =
          result['message'] ??
          'Admin account created. Temporary password sent to $email';

      // Log org creation + admin creation (fire-and-forget)
      final actor = firebase.currentUser;
      if (actor != null) {
        ActivityLogService.instance.log(
          actionType: ActivityLogService.actionOrgCreated,
          userId: actor.uid,
          email: actor.email ?? '',
          role: 'primary_admin',
          organizationName: orgName,
          targetEmail: email,
        );
        ActivityLogService.instance.log(
          actionType: ActivityLogService.actionAdminCreated,
          userId: actor.uid,
          email: actor.email ?? '',
          role: 'primary_admin',
          organizationName: orgName,
          targetEmail: email,
        );
      }

      // Clear form
      _clearForm();
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  void _clearForm() {
    organizationNameController.clear();
    addressController.clear();
    adminEmailController.clear();
    selectedCity = null;
    selectedIndustry = null;
    selectedEmployeeRange = null;
  }

  void clearMessages() {
    successMessage = null;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    organizationNameController.dispose();
    addressController.dispose();
    adminEmailController.dispose();
    super.dispose();
  }
}
