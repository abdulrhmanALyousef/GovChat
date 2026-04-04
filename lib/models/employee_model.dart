import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  final String? id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String nationalId;
  final String organizationId;
  final String organizationName;
  final String department;
  final String status; // pending, approved, rejected
  final DateTime? createdAt;

  EmployeeModel({
    this.id,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.email,
    required this.nationalId,
    required this.organizationId,
    required this.organizationName,
    required this.department,
    this.status = 'pending',
    this.createdAt,
  });

  String get fullName =>
      middleName.isNotEmpty ? '$firstName $middleName $lastName' : '$firstName $lastName';

  factory EmployeeModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return EmployeeModel(
      id: id,
      firstName: json['firstName'] ?? '',
      middleName: json['middleName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      nationalId: json['nationalId'] ?? '',
      organizationId: json['organizationId'] ?? '',
      organizationName: json['organizationName'] ?? '',
      department: json['department'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'email': email,
      'nationalId': nationalId,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'department': department,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

