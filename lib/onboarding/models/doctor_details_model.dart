/// DoctorDetailsModel - Full doctor details for local-first onboarding.
///
/// This table contains all doctor-specific fields.
/// Written from the Doctor Details Screen.
///
/// Firestore mirror happens ONLY after this table is complete.
library;

class DoctorDetailsModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Doctor's full name
  final String fullName;
  
  /// Doctor's email address
  final String email;
  
  /// Doctor's phone number
  final String phoneNumber;
  
  /// Doctor's medical specialization (e.g., Cardiology, Neurology)
  final String specialization;
  
  /// Medical license number
  final String licenseNumber;
  
  /// Years of professional experience
  final int yearsOfExperience;
  
  /// Clinic or hospital name where doctor practices
  final String clinicOrHospitalName;
  
  /// Doctor's address
  final String address;
  
  /// Whether doctor's credentials are verified (default: false)
  final bool isVerified;
  
  /// Whether all required fields are complete
  final bool isComplete;
  
  /// Timestamp when this record was created
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const DoctorDetailsModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.specialization,
    required this.licenseNumber,
    required this.yearsOfExperience,
    required this.clinicOrHospitalName,
    required this.address,
    this.isVerified = false,
    this.isComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  DoctorDetailsModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (fullName.isEmpty) {
      throw ArgumentError('fullName cannot be empty');
    }
    if (specialization.isEmpty) {
      throw ArgumentError('specialization cannot be empty');
    }
    if (licenseNumber.isEmpty) {
      throw ArgumentError('licenseNumber cannot be empty');
    }
    if (yearsOfExperience < 0) {
      throw ArgumentError('yearsOfExperience cannot be negative');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns true if all required fields are filled.
  bool get checkIsComplete =>
      fullName.isNotEmpty &&
      specialization.isNotEmpty &&
      licenseNumber.isNotEmpty &&
      clinicOrHospitalName.isNotEmpty;

  DoctorDetailsModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? specialization,
    String? licenseNumber,
    int? yearsOfExperience,
    String? clinicOrHospitalName,
    String? address,
    bool? isVerified,
    bool? isComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorDetailsModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      specialization: specialization ?? this.specialization,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      clinicOrHospitalName: clinicOrHospitalName ?? this.clinicOrHospitalName,
      address: address ?? this.address,
      isVerified: isVerified ?? this.isVerified,
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'full_name': fullName,
    'email': email,
    'phone_number': phoneNumber,
    'specialization': specialization,
    'license_number': licenseNumber,
    'years_of_experience': yearsOfExperience,
    'clinic_or_hospital_name': clinicOrHospitalName,
    'address': address,
    'is_verified': isVerified,
    'is_complete': isComplete,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory DoctorDetailsModel.fromJson(Map<String, dynamic> json) => DoctorDetailsModel(
    uid: json['uid'] as String,
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phoneNumber: json['phone_number'] as String? ?? '',
    specialization: json['specialization'] as String? ?? '',
    licenseNumber: json['license_number'] as String? ?? '',
    yearsOfExperience: json['years_of_experience'] as int? ?? 0,
    clinicOrHospitalName: json['clinic_or_hospital_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    isVerified: json['is_verified'] as bool? ?? false,
    isComplete: json['is_complete'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'DoctorDetailsModel(uid: $uid, fullName: $fullName, specialization: $specialization)';
}
