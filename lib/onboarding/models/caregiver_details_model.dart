/// CaregiverDetailsModel - Full caregiver details for local-first onboarding.
///
/// This table contains all caregiver-specific fields.
/// Written from the Caregiver Details Screen.
///
/// Firestore mirror happens ONLY after this table is complete.
library;

class CaregiverDetailsModel {
  /// Firebase UID - primary key
  final String uid;
  
  /// Caregiver's name
  final String caregiverName;
  
  /// Caregiver's phone number
  final String phoneNumber;
  
  /// Caregiver's email address
  final String emailAddress;
  
  /// Relation to the patient (e.g., "Son", "Daughter", "Spouse")
  final String relationToPatient;
  
  /// Name of the patient being cared for
  final String patientName;
  
  /// Whether all required fields are complete
  final bool isComplete;
  
  /// Timestamp when this record was created
  final DateTime createdAt;
  
  /// Timestamp when this record was last updated
  final DateTime updatedAt;

  const CaregiverDetailsModel({
    required this.uid,
    required this.caregiverName,
    required this.phoneNumber,
    required this.emailAddress,
    required this.relationToPatient,
    required this.patientName,
    this.isComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validates this model and checks completeness.
  CaregiverDetailsModel validate() {
    if (uid.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    if (caregiverName.isEmpty) {
      throw ArgumentError('caregiverName cannot be empty');
    }
    if (phoneNumber.isEmpty) {
      throw ArgumentError('phoneNumber cannot be empty');
    }
    if (emailAddress.isEmpty) {
      throw ArgumentError('emailAddress cannot be empty');
    }
    if (relationToPatient.isEmpty) {
      throw ArgumentError('relationToPatient cannot be empty');
    }
    if (patientName.isEmpty) {
      throw ArgumentError('patientName cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt cannot be before createdAt');
    }
    return this;
  }

  /// Returns true if all required fields are filled.
  bool get checkIsComplete =>
      caregiverName.isNotEmpty &&
      phoneNumber.isNotEmpty &&
      emailAddress.isNotEmpty &&
      relationToPatient.isNotEmpty &&
      patientName.isNotEmpty;

  CaregiverDetailsModel copyWith({
    String? uid,
    String? caregiverName,
    String? phoneNumber,
    String? emailAddress,
    String? relationToPatient,
    String? patientName,
    bool? isComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CaregiverDetailsModel(
      uid: uid ?? this.uid,
      caregiverName: caregiverName ?? this.caregiverName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      relationToPatient: relationToPatient ?? this.relationToPatient,
      patientName: patientName ?? this.patientName,
      isComplete: isComplete ?? this.isComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'caregiver_name': caregiverName,
    'phone_number': phoneNumber,
    'email_address': emailAddress,
    'relation_to_patient': relationToPatient,
    'patient_name': patientName,
    'is_complete': isComplete,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CaregiverDetailsModel.fromJson(Map<String, dynamic> json) => CaregiverDetailsModel(
    uid: json['uid'] as String,
    caregiverName: json['caregiver_name'] as String? ?? '',
    phoneNumber: json['phone_number'] as String? ?? '',
    emailAddress: json['email_address'] as String? ?? '',
    relationToPatient: json['relation_to_patient'] as String? ?? '',
    patientName: json['patient_name'] as String? ?? '',
    isComplete: json['is_complete'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  );

  @override
  String toString() => 'CaregiverDetailsModel(uid: $uid, caregiverName: $caregiverName, isComplete: $isComplete)';
}
