import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String? id;
  final String name;
  final String country;
  final String city;
  final String address;
  final String industry;
  final String employeeRange;
  final String adminEmail;
  final String adminUid;
  final String status;
  final DateTime? createdAt;

  OrganizationModel({
    this.id,
    required this.name,
    required this.country,
    required this.city,
    this.address = '',
    this.industry = '',
    this.employeeRange = '',
    required this.adminEmail,
    required this.adminUid,
    this.status = 'active',
    this.createdAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return OrganizationModel(
      id: id,
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      industry: json['industry'] ?? '',
      employeeRange: json['employeeRange'] ?? '',
      adminEmail: json['adminEmail'] ?? '',
      adminUid: json['adminUid'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'city': city,
      'address': address,
      'industry': industry,
      'employeeRange': employeeRange,
      'adminEmail': adminEmail,
      'adminUid': adminUid,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
