import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:projects/l10n/app_localizations.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/services/otp_service.dart';
import '../../core/theme/app_color.dart';
import '../../models/organization_model.dart';
import '../login_screen.dart';
import '../otp_verification_screen.dart';

class RequestAccessController extends ChangeNotifier {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  String? selectedOrganizationId;
  String? selectedOrganizationName;
  String? selectedDepartment;
  bool isLoading = false;
  bool isLoadingOrgs = true;
  String? errorMessage;

  List<OrganizationModel> organizations = [];

  final List<String> departments = [
    'IT Department',
    'HR Department',
    'Operations',
    'Security',
    'Other',
  ];

  RequestAccessController() {
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    isLoadingOrgs = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseService.instance.firestore
          .collection('organizations')
          .where('status', isEqualTo: 'active')
          .get();

      organizations = snapshot.docs
          .map((doc) => OrganizationModel.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error loading organizations: $e');
    }

    isLoadingOrgs = false;
    notifyListeners();
  }

  void setOrganization(String? orgId) {
    selectedOrganizationId = orgId;
    final org = organizations.firstWhere(
      (o) => o.id == orgId,
      orElse: () => organizations.first,
    );
    selectedOrganizationName = org.name;
    notifyListeners();
  }

  void setDepartment(String? value) {
    selectedDepartment = value;
    notifyListeners();
  }

  Future<void> submitRequest(BuildContext context) async {
    if (!formKey.currentState!.validate()) return;

    final l = AppLocalizations.of(context)!;

    if (selectedOrganizationId == null) {
      errorMessage = l.pleaseSelectOrganization;
      notifyListeners();
      return;
    }

    if (selectedDepartment == null) {
      errorMessage = l.pleaseSelectDepartment;
      notifyListeners();
      return;
    }

    final localPhone = phoneController.text.trim();

    // Convert from Saudi local format (05XXXXXXXX) to international (+966...)
    String phone;
    try {
      phone = OtpService.formatSaudiPhone(localPhone);
    } on FormatException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return;
    }

    // Step 1: Send OTP to employee phone
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await OtpService.instance.sendOtp(phone: phone, purpose: 'access_request');
    } on Exception catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = false;
    notifyListeners();

    if (!context.mounted) return;

    // Step 2: OTP verification screen
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phone: phone,
          purpose: 'access_request',
        ),
      ),
    ) ?? false;

    if (!verified || !context.mounted) return;

    // Step 3: OTP confirmed — create the employee request
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('createEmployeeRequest');

      await callable.call({
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
        'nationalId': nationalIdController.text.trim(),
        'organizationId': selectedOrganizationId,
        'organizationName': selectedOrganizationName,
        'department': selectedDepartment,
        'phoneNumber': phone,
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.requestSubmittedSuccess),
          backgroundColor: AppColors.primaryColor,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        errorMessage = l.emailAlreadyRegistered;
      } else if (e.code == 'failed-precondition') {
        errorMessage = l.otpVerificationFailed;
      } else {
        errorMessage = e.message ?? l.somethingWentWrong;
      }
    } catch (e) {
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  void backToLogin(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nationalIdController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}
