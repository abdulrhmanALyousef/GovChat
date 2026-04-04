import 'package:flutter/material.dart';
import '../../../../../core/datasource/remote_data/firebase_service.dart';

class OrganizationsController extends ChangeNotifier {
  final TextEditingController organizationNameController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController adminEmailController = TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

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

    try {
      final result = await firebase.createOrganizationWithAdmin(
        email: email,
        organizationName: organizationNameController.text.trim(),
        country: countryController.text.trim(),
        city: cityController.text.trim(),
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

      successMessage = result['message'] ??
          'Admin account created. Temporary password sent to $email';

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
    countryController.clear();
    cityController.clear();
    addressController.clear();
    adminEmailController.clear();
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
    countryController.dispose();
    cityController.dispose();
    addressController.dispose();
    adminEmailController.dispose();
    super.dispose();
  }
}
