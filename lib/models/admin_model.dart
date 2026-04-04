import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String email;
  final String role;
  final String? organizationId;
  final String? organizationName;
  final bool mustChangePassword;
  final bool firstLogin;
  final DateTime? createdAt;

  AdminModel({
    required this.uid,
    required this.email,
    required this.role,
    this.organizationId,
    this.organizationName,
    this.mustChangePassword = true,
    this.firstLogin = true,
    this.createdAt,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      organizationId: json['organizationId'],
      organizationName: json['organizationName'],
      mustChangePassword: json['mustChangePassword'] ?? true,
      firstLogin: json['firstLogin'] ?? true,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'mustChangePassword': mustChangePassword,
      'firstLogin': firstLogin,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
