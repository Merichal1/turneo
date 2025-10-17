import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String jobRole;
  final String city;
  final bool hasCar;
  final bool isActive;
  final int experienceYears;
  final int age;

  const UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.jobRole = '',
    this.city = '',
    this.hasCar = false,
    this.isActive = true,
    this.experienceYears = 0,
    this.age = 0,
  });

  /// ←——— AQUI ESTÁ EL copyWith ———→
  UserModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? jobRole,
    String? city,
    bool? hasCar,
    bool? isActive,
    int? experienceYears,
    int? age,
  }) {
    return UserModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      jobRole: jobRole ?? this.jobRole,
      city: city ?? this.city,
      hasCar: hasCar ?? this.hasCar,
      isActive: isActive ?? this.isActive,
      experienceYears: experienceYears ?? this.experienceYears,
      age: age ?? this.age,
    );
  }

  // --------- Firestore helpers ----------
  factory UserModel.fromMap(String id, Map<String, dynamic> m) {
    return UserModel(
      id: id,
      displayName: (m['displayName'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      jobRole: (m['jobRole'] ?? '') as String,
      city: (m['city'] ?? '') as String,
      hasCar: (m['hasCar'] ?? false) as bool,
      isActive: (m['isActive'] ?? true) as bool,
      experienceYears: (m['experienceYears'] ?? 0) as int,
      age: (m['age'] ?? 0) as int,
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'jobRole': jobRole,
        'city': city,
        'hasCar': hasCar,
        'isActive': isActive,
        'experienceYears': experienceYears,
        'age': age,
      };
}


