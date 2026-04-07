import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  final String? id;
  final String name; // single name field
  final String email;
  final String nationalId;
  final String organizationId;
  final String organizationName;
  final String department;
  final String departmentId;
  final String displayId;
  final String status; // pending, approved, rejected
  final DateTime? createdAt;

  EmployeeModel({
    this.id,
    required this.name,
    required this.email,
    required this.nationalId,
    required this.organizationId,
    required this.organizationName,
    required this.department,
    this.departmentId = '',
    this.displayId = '',
    this.status = 'pending',
    this.createdAt,
  });

  String get fullName => name;

  factory EmployeeModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final nameValue = (json['name'] ?? '').toString().trim();
    return EmployeeModel(
      id: id,
      name: nameValue.isNotEmpty ? nameValue : '— لا يوجد اسم —',
      email: json['email'] ?? '',
      nationalId: json['nationalId'] ?? '',
      organizationId: json['organizationId'] ?? '',
      organizationName: json['organizationName'] ?? '',
      department: json['department'] ?? '',
      departmentId: json['departmentId'] ?? json['department'] ?? '',
      displayId: json['displayId'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'nationalId': nationalId,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'department': department,
      'departmentId': departmentId,
      'displayId': displayId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
