import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequestModel {
  final String? id;
  final String? uid;
  final String email;
  final String firstName;
  final String middleName;
  final String lastName;
  final String fullName;
  final String organizationId;
  final String organizationName;
  final String department;
  final String? departmentId;
  final String displayId;
  final String status;
  final DateTime? createdAt;

  AccessRequestModel({
    this.id,
    this.uid,
    required this.email,
    required this.firstName,
    this.middleName = '',
    required this.lastName,
    required this.fullName,
    required this.organizationId,
    required this.organizationName,
    required this.department,
    this.departmentId,
    this.displayId = '',
    this.status = 'pending',
    this.createdAt,
  });

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (middleName.isNotEmpty) {
      return '$firstName $middleName $lastName';
    }
    return '$firstName $lastName';
  }

  factory AccessRequestModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return AccessRequestModel(
      id: id,
      uid: json['uid'],
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      middleName: json['middleName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      organizationId: json['organizationId'] ?? '',
      organizationName: json['organizationName'] ?? '',
      department: json['department'] ?? '',
      departmentId: json['departmentId'],
      displayId: json['displayId'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'fullName': fullName.isNotEmpty ? fullName : displayName,
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
