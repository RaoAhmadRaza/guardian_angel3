/// PatientDetailsModel - Full patient details for local-first onboarding.
///
/// This table contains all patient-specific fields.
/// Written from the Patient Details Screen.
///
/// Firestore mirror happens ONLY after this table is complete.
library;

class PatientDetailsModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Patient's gender (Male / Female)
  final String gender;
  
  /// Patient's full name
  final String name;
  
  /// Patient's phone number
  final String phoneNumber;
  
  /// Patient's address
  final String address;
  
  /// Patient's medical history
  final String medicalHistory;
  
  /// Whether all required fields are complete
  final bool isComplete;
  
  /// Timestamp when this record was created
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const PatientDetailsModel({
    required this.uid,
    required this.gender,
    required this.name,
    required this.phoneNumber,
    required this.address,
    required this.medicalHistory,
    this.isComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model.
  PatientDetailsModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (gender.isEmpty) {
      throw ArgumentError('gender cannot be empty');
    }
    if (gender != 'male' && gender != 'female') {
      throw ArgumentError('gender must be "male" or "female"');
    }
    if (name.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (phoneNumber.isEmpty) {
      throw ArgumentError('phoneNumber cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns true if all required fields are filled.
  bool get checkIsComplete =>
      gender.isNotEmpty &&
      name.isNotEmpty &&
      phoneNumber.isNotEmpty;

  PatientDetailsModel copyWith({
    String? uid,
    String? gender,
    String? name,
    String? phoneNumber,
    String? address,
    String? medicalHistory,
    bool? isComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientDetailsModel(
      uid: uid ?? this.uid,
      gender: gender ?? this.gender,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'gender': gender,
    'name': name,
    'phone_number': phoneNumber,
    'address': address,
    'medical_history': medicalHistory,
    'is_complete': isComplete,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory PatientDetailsModel.fromJson(Map<String, dynamic> json) => PatientDetailsModel(
    uid: json['uid'] as String,
    gender: json['gender'] as String? ?? '',
    name: json['name'] as String? ?? '',
    phoneNumber: json['phone_number'] as String? ?? '',
    address: json['address'] as String? ?? '',
    medicalHistory: json['medical_history'] as String? ?? '',
    isComplete: json['is_complete'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'PatientDetailsModel(uid: $uid, name: $name, gender: $gender, isComplete: $isComplete)';
}
