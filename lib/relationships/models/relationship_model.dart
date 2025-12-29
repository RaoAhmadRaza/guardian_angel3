/// RelationshipModel - Links Patient ↔ Caregiver with explicit UIDs.
///
/// This is the core entity for patient-caregiver relationships.
/// Used for: chat permissions, data access, SOS escalation, doctor visibility.
///
/// Rules:
/// - patientId is always known (creator)
/// - caregiverId is null until accepted
/// - Only ONE active relationship per caregiver
/// - Patient may have MULTIPLE caregivers
/// - Invite code must be unique
/// - Invite code expires if relationship is revoked
library;

/// Status of a patient-caregiver relationship.
enum RelationshipStatus {
  /// Relationship created, waiting for caregiver to accept
  pending,
  
  /// Relationship active and functional
  active,
  
  /// Relationship terminated
  revoked,
}

/// Extension to convert enum to/from string.
extension RelationshipStatusExtension on RelationshipStatus {
  String get value {
    switch (this) {
      case RelationshipStatus.pending:
        return 'pending';
      case RelationshipStatus.active:
        return 'active';
      case RelationshipStatus.revoked:
        return 'revoked';
    }
  }

  static RelationshipStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return RelationshipStatus.pending;
      case 'active':
        return RelationshipStatus.active;
      case 'revoked':
        return RelationshipStatus.revoked;
      default:
        throw ArgumentError('Invalid RelationshipStatus: $value');
    }
  }
}

/// Valid permission scopes for relationships.
const validRelationshipPermissions = <String>{
  'chat',
  'view_vitals',
  'sos',
  'view_location',
  'view_medications',
};

/// Validation error for relationship data integrity.
class RelationshipValidationError implements Exception {
  final String message;
  RelationshipValidationError(this.message);
  @override
  String toString() => 'RelationshipValidationError: $message';
}

/// Core relationship model linking patient and caregiver.
class RelationshipModel {
  /// Unique identifier (UUID)
  final String id;
  
  /// Firebase UID of the patient (always set)
  final String patientId;
  
  /// Firebase UID of the caregiver (null until accepted)
  final String? caregiverId;
  
  /// Current status of the relationship
  final RelationshipStatus status;
  
  /// Permission scopes granted to caregiver
  final List<String> permissions;
  
  /// Human-readable invite code for caregiver to claim
  final String inviteCode;
  
  /// When this relationship was created
  final DateTime createdAt;
  
  /// When this relationship was last updated
  final DateTime updatedAt;
  
  /// UID of the user who created this relationship (usually patientId)
  final String createdBy;

  const RelationshipModel({
    required this.id,
    required this.patientId,
    this.caregiverId,
    required this.status,
    required this.permissions,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  /// Validates this model.
  /// Throws [RelationshipValidationError] if invalid.
  /// Returns this instance for method chaining.
  RelationshipModel validate() {
    if (id.isEmpty) {
      throw RelationshipValidationError('id cannot be empty');
    }
    if (patientId.isEmpty) {
      throw RelationshipValidationError('patientId cannot be empty');
    }
    if (inviteCode.isEmpty) {
      throw RelationshipValidationError('inviteCode cannot be empty');
    }
    if (createdBy.isEmpty) {
      throw RelationshipValidationError('createdBy cannot be empty');
    }
    if (updatedAt.isBefore(createdAt)) {
      throw RelationshipValidationError('updatedAt cannot be before createdAt');
    }
    
    // Validate permissions
    for (final perm in permissions) {
      if (!validRelationshipPermissions.contains(perm)) {
        throw RelationshipValidationError('Invalid permission: $perm');
      }
    }
    
    // If active, caregiverId must be set
    if (status == RelationshipStatus.active && (caregiverId == null || caregiverId!.isEmpty)) {
      throw RelationshipValidationError('Active relationship must have caregiverId');
    }
    
    return this;
  }

  /// Returns true if this relationship is usable for data access.
  bool get isUsable => status == RelationshipStatus.active && caregiverId != null;

  /// Returns true if this relationship can be accepted.
  bool get canBeAccepted => status == RelationshipStatus.pending && caregiverId == null;

  /// Checks if a specific permission is granted.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Creates a copy with updated fields.
  RelationshipModel copyWith({
    String? id,
    String? patientId,
    String? caregiverId,
    RelationshipStatus? status,
    List<String>? permissions,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return RelationshipModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      caregiverId: caregiverId ?? this.caregiverId,
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
    'caregiver_id': caregiverId,
    'status': status.value,
    'permissions': permissions,
    'invite_code': inviteCode,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'created_by': createdBy,
  }..removeWhere((k, v) => v == null);

  /// Creates from JSON (Firestore).
  factory RelationshipModel.fromJson(Map<String, dynamic> json) => RelationshipModel(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    caregiverId: json['caregiver_id'] as String?,
    status: RelationshipStatusExtension.fromString(json['status'] as String),
    permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? const [],
    inviteCode: json['invite_code'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    createdBy: json['created_by'] as String,
  );

  @override
  String toString() => 'RelationshipModel(id: $id, patient: $patientId, caregiver: $caregiverId, status: ${status.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
