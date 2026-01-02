/// DoctorRelationshipModel - Links Patient ↔ Doctor with explicit UIDs.
///
/// This is the core entity for patient-doctor relationships.
/// Used for: clinical chat, health data access, medical notes, emergency visibility.
///
/// Rules:
/// - patientId is always known (creator)
/// - doctorId is null until accepted
/// - A doctor may have MULTIPLE patients
/// - A patient may have MULTIPLE doctors
/// - Invite code must be unique
/// - Invite code expires if relationship is revoked
/// - Doctor relationships are non-exclusive
library;

/// Valid permission scopes for doctor relationships.
const validDoctorRelationshipPermissions = <String>{
  'chat',
  'view_records',
  'view_vitals',
  'notes',
  'view_medications',
  'emergency_access',
};

/// Validation error for doctor relationship data integrity.
class DoctorRelationshipValidationError implements Exception {
  final String message;
  DoctorRelationshipValidationError(this.message);
  @override
  String toString() => 'DoctorRelationshipValidationError: $message';
}

/// Status of a patient-doctor relationship (reuses RelationshipStatus semantics).
enum DoctorRelationshipStatus {
  /// Relationship created, waiting for doctor to accept
  pending,
  
  /// Relationship active and functional
  active,
  
  /// Relationship terminated
  revoked,
}

/// Extension to convert enum to/from string.
extension DoctorRelationshipStatusExtension on DoctorRelationshipStatus {
  String get value {
    switch (this) {
      case DoctorRelationshipStatus.pending:
        return 'pending';
      case DoctorRelationshipStatus.active:
        return 'active';
      case DoctorRelationshipStatus.revoked:
        return 'revoked';
    }
  }

  static DoctorRelationshipStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return DoctorRelationshipStatus.pending;
      case 'active':
        return DoctorRelationshipStatus.active;
      case 'revoked':
        return DoctorRelationshipStatus.revoked;
      default:
        throw ArgumentError('Invalid DoctorRelationshipStatus: $value');
    }
  }
}

/// Core relationship model linking patient and doctor.
class DoctorRelationshipModel {
  /// Unique identifier (UUID)
  final String id;
  
  /// Firebase UID of the patient (always set)
  final String patientId;
  
  /// Firebase UID of the doctor (null until accepted)
  final String? doctorId;
  
  /// Current status of the relationship
  final DoctorRelationshipStatus status;
  
  /// Permission scopes granted to doctor
  final List<String> permissions;
  
  /// Human-readable invite code for doctor to claim
  final String inviteCode;
  
  /// When this relationship was created
  final DateTime createdAt;
  
  /// When this relationship was last updated
  final DateTime updatedAt;
  
  /// UID of the user who created this relationship (usually patientId)
  final String createdBy;

  const DoctorRelationshipModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.status,
    required this.permissions,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  /// Validates this model.
  /// Throws [DoctorRelationshipValidationError] if invalid.
  /// Returns this instance for method chaining.
  DoctorRelationshipModel validate() {
    if (id.isEmpty) {
      throw DoctorRelationshipValidationError('id cannot be empty');
    }
    if (patientId.isEmpty) {
      throw DoctorRelationshipValidationError('patientId cannot be empty');
    }
    if (inviteCode.isEmpty) {
      throw DoctorRelationshipValidationError('inviteCode cannot be empty');
    }
    if (createdBy.isEmpty) {
      throw DoctorRelationshipValidationError('createdBy cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw DoctorRelationshipValidationError('updatedAt cannot be before createdAt');
    }
    
    // Validate permissions
    for (final perm in permissions) {
      if (!validDoctorRelationshipPermissions.contains(perm)) {
        throw DoctorRelationshipValidationError('Invalid permission: $perm');
      }
    }
    
    // If active, doctorId must be set
    if (status == DoctorRelationshipStatus.active && (doctorId == null || doctorId!.isEmpty)) {
      throw DoctorRelationshipValidationError('Active relationship must have doctorId');
    }
    
    return this;
  }

  /// Returns true if this relationship is usable for data access.
  bool get isUsable => status == DoctorRelationshipStatus.active && doctorId != null;

  /// Returns true if this relationship can be accepted.
  bool get canBeAccepted => status == DoctorRelationshipStatus.pending && doctorId == null;

  /// Checks if a specific permission is granted.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Creates a copy with updated fields.
  DoctorRelationshipModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    DoctorRelationshipStatus? status,
    List<String>? permissions,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return DoctorRelationshipModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      status: status ?? this.status,
      permissions: permissions ?? List.from(this.permissions),
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Converts to JSON for Firestore.
  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_id': patientId,
    'doctor_id': doctorId,
    'status': status.value,
    'permissions': permissions,
    'invite_code': inviteCode,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'created_by': createdBy,
  }..removeWhere((k, v) => v == null);

  /// Creates from JSON (Firestore).
  factory DoctorRelationshipModel.fromJson(Map<String, dynamic> json) => DoctorRelationshipModel(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    doctorId: json['doctor_id'] as String?,
    status: DoctorRelationshipStatusExtension.fromString(json['status'] as String),
    permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
    inviteCode: json['invite_code'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    createdBy: json['created_by'] as String,
  );

  @override
  String toString() => 'DoctorRelationshipModel(id: $id, patient: $patientId, doctor: $doctorId, status: ${status.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorRelationshipModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
