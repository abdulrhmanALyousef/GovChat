import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // ─── Getters ───
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  User? get currentUser => _auth.currentUser;

  // ─── Create Organization + Admin via Cloud Function ───
  Future<Map<String, dynamic>> createOrganizationWithAdmin({
    required String email,
    required String organizationName,
    required String country,
    required String city,
    String? address,
    String? industry,
    String? employeeRange,
  }) async {
    try {
      final callable = _functions.httpsCallable('createAdminWithCode');

      final result = await callable.call({
        'email': email,
        'organizationName': organizationName,
        'country': country,
        'city': city,
        'address': address ?? '',
        'industry': industry ?? '',
        'employeeRange': employeeRange ?? '',
      });

      final data = result.data as Map<String, dynamic>;
      return {
        'success': data['success'] ?? false,
        'uid': data['uid'],
        'emailSent': data['emailSent'] ?? false,
        'message': data['message'],
      };
    } catch (e) {
      String errorMessage = e.toString();
      if (e is FirebaseException) {
        errorMessage = e.message ?? e.toString();
      }
      return {'success': false, 'error': errorMessage};
    }
  }
}
