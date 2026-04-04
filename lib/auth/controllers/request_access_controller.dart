import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/datasource/remote_data/firebase_service.dart';
import '../../core/theme/App_color.dart';
import '../../models/organization_model.dart';
import '../login_screen.dart';

class RequestAccessController extends ChangeNotifier {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nationalIdController = TextEditingController();

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

    if (selectedOrganizationId == null) {
      errorMessage = 'Please select an organization';
      notifyListeners();
      return;
    }

    if (selectedDepartment == null) {
      errorMessage = 'Please select a department';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Call Cloud Function - creates Auth user + users doc (pending) + accessRequests + notification + email
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createEmployeeRequest');

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
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted! Waiting for admin approval.'),
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
        errorMessage = 'This email is already registered.';
      } else {
        errorMessage = e.message ?? 'Something went wrong.';
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
    super.dispose();
  }
}