/// Authoritative TypeId Registry
///
/// ╔══════════════════════════════════════════════════════════════════════════╗
/// ║  THIS IS THE SINGLE SOURCE OF TRUTH FOR ALL HIVE TYPE IDS.              ║
/// ║                                                                          ║
/// ║  ❌ DO NOT define TypeIds anywhere else.                                 ║
/// ║  ❌ DO NOT use magic numbers in @HiveType annotations.                   ║
/// ║  ✅ ALWAYS import this file and use TypeIds.xxx constants.               ║
/// ╚══════════════════════════════════════════════════════════════════════════╝
///
/// TypeId Allocation Ranges:
///   0-9:    Home Automation Core (generated adapters)
///   10-19:  Persistence Layer Core (manual adapters)
///   20-29:  Sync & Failure Tracking
///   30-39:  Services & Transactions
///   40-49:  Reserved for future use
///
/// MIGRATION NOTE:
/// If you need to change a TypeId, you MUST:
/// 1. Create a migration in lib/persistence/migrations/
/// 2. Update the SchemaValidator expected adapters
/// 3. Bump the schema version
library;

/// Authoritative TypeId constants for all Hive adapters.
///
/// Usage in generated adapters:
/// ```dart
/// import 'package:guardian_angel_fyp/persistence/type_ids.dart';
/// 
/// @HiveType(typeId: TypeIds.roomHive)
/// class RoomModelHive { ... }
/// ```
///
/// Usage in manual adapters:
/// ```dart
/// import '../type_ids.dart';
/// 
/// class RoomAdapter extends TypeAdapter<RoomModel> {
///   @override
///   final int typeId = TypeIds.room;
/// }
/// ```
abstract final class TypeIds {
  TypeIds._(); // Prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME AUTOMATION CORE (0-9) - Generated Hive Adapters
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// RoomModelHive - Home automation room model
  /// File: lib/home automation/src/data/hive_adapters/room_model_hive.dart
  static const int roomHive = 0;
  
  /// DeviceModelHive - Home automation device model  
  /// File: lib/home automation/src/data/hive_adapters/device_model_hive.dart
  static const int deviceHive = 1;
  
  // Reserved: 2-9 for future home automation models

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE LAYER CORE (10-19) - Manual TypeAdapters
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// RoomModel - Core room model (persistence layer)
  /// Adapter: lib/persistence/adapters/room_adapter.dart
  static const int room = 10;
  
  /// PendingOp - Queue operation model
  /// Adapter: lib/persistence/adapters/pending_op_adapter.dart
  static const int pendingOp = 11;
  
  /// DeviceModel - Core device model (persistence layer)
  /// Adapter: lib/persistence/adapters/device_adapter.dart
  static const int device = 12;
  
  /// VitalsModel - Health vitals model
  /// Adapter: lib/persistence/adapters/vitals_adapter.dart
  static const int vitals = 13;
  
  /// UserProfileModel - User profile model
  /// Adapter: lib/persistence/adapters/user_profile_adapter.dart
  static const int userProfile = 14;
  
  /// SessionModel - User session model
  /// Adapter: lib/persistence/adapters/session_adapter.dart
  static const int session = 15;
  
  /// FailedOpModel - Failed operation model
  /// Adapter: lib/persistence/adapters/failed_op_adapter.dart
  static const int failedOp = 16;
  
  /// AuditLogRecord - Audit log record
  /// Adapter: lib/persistence/adapters/audit_log_adapter.dart
  static const int auditLogRecord = 17;
  
  /// SettingsModel - App settings model
  /// Adapter: lib/persistence/adapters/settings_adapter.dart
  static const int settings = 18;
  
  /// AssetsCacheEntry - Cached assets model
  /// Adapter: lib/persistence/adapters/assets_cache_adapter.dart
  static const int assetsCache = 19;

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC & FAILURE TRACKING (20-29)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// SyncFailure - Sync failure record
  /// File: lib/models/sync_failure.dart
  static const int syncFailure = 24;
  
  /// SyncFailureStatus - Enum for sync failure status
  /// File: lib/models/sync_failure.dart
  static const int syncFailureStatus = 25;
  
  /// SyncFailureSeverity - Enum for sync failure severity
  /// File: lib/models/sync_failure.dart
  static const int syncFailureSeverity = 26;

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVICES & TRANSACTIONS (30-39)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// TransactionRecord - Atomic transaction record
  /// File: lib/services/models/transaction_record.dart
  static const int transactionRecord = 30;
  
  /// LockRecord - Distributed lock record
  /// File: lib/services/models/lock_record.dart
  static const int lockRecord = 32;
  
  /// AuditLogEntry - Audit log entry (services layer)
  /// File: lib/services/models/audit_log_entry.dart
  static const int auditLogEntry = 33;
  
  /// AuditLogArchive - Audit log archive metadata
  /// File: lib/services/models/audit_log_entry.dart
  static const int auditLogArchive = 34;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONBOARDING & USER TABLES (40-46, 51-52 for Doctor)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// UserBaseModel - Auth basics (email, fullName, profileImageUrl)
  /// Adapter: lib/persistence/adapters/user_base_adapter.dart
  static const int userBase = 40;
  
  /// CaregiverUserModel - Caregiver role assignment
  /// Adapter: lib/persistence/adapters/caregiver_user_adapter.dart
  static const int caregiverUser = 41;
  
  /// CaregiverDetailsModel - Full caregiver details
  /// Adapter: lib/persistence/adapters/caregiver_details_adapter.dart
  static const int caregiverDetails = 42;
  
  /// PatientUserModel - Patient role assignment + age
  /// Adapter: lib/persistence/adapters/patient_user_adapter.dart
  static const int patientUser = 43;
  
  /// PatientDetailsModel - Full patient details
  /// Adapter: lib/persistence/adapters/patient_details_adapter.dart
  static const int patientDetails = 44;
  
  /// RelationshipModel - Patient-Caregiver relationship
  /// Adapter: lib/persistence/adapters/relationship_adapter.dart
  static const int relationship = 45;
  
  /// RelationshipStatus - Enum for relationship status
  /// Adapter: lib/persistence/adapters/relationship_adapter.dart
  static const int relationshipStatus = 46;

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT SYSTEM (47-50)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// ChatThreadModel - Chat thread between Patient and Caregiver
  /// Adapter: lib/persistence/adapters/chat_adapter.dart
  static const int chatThread = 47;
  
  /// ChatMessageModel - Individual chat message
  /// Adapter: lib/persistence/adapters/chat_adapter.dart
  static const int chatMessage = 48;
  
  /// ChatMessageType - Enum for message type (text, image, voice, system)
  /// Adapter: lib/persistence/adapters/chat_adapter.dart
  static const int chatMessageType = 49;
  
  /// ChatMessageLocalStatus - Enum for local message status
  /// Adapter: lib/persistence/adapters/chat_adapter.dart
  static const int chatMessageLocalStatus = 50;

  // ═══════════════════════════════════════════════════════════════════════════
  // DOCTOR ROLE (51-52)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// DoctorUserModel - Doctor role assignment
  /// Adapter: lib/persistence/adapters/doctor_user_adapter.dart
  static const int doctorUser = 51;
  
  /// DoctorDetailsModel - Full doctor details
  /// Adapter: lib/persistence/adapters/doctor_details_adapter.dart
  static const int doctorDetails = 52;

  // ═══════════════════════════════════════════════════════════════════════════
  // DOCTOR-PATIENT RELATIONSHIPS (53-54)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// DoctorRelationshipModel - Patient-Doctor relationship
  /// Adapter: lib/persistence/adapters/doctor_relationship_adapter.dart
  static const int doctorRelationship = 53;
  
  /// DoctorRelationshipStatus - Enum for doctor relationship status
  /// Adapter: lib/persistence/adapters/doctor_relationship_adapter.dart
  static const int doctorRelationshipStatus = 54;

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH DATA PERSISTENCE (55-59)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// StoredHealthReading - Persisted health reading (all types)
  /// Adapter: lib/persistence/adapters/stored_health_reading_adapter.dart
  static const int storedHealthReading = 55;
  
  /// StoredHealthReadingType - Enum for reading type discriminator
  /// Adapter: lib/persistence/adapters/stored_health_reading_adapter.dart
  static const int storedHealthReadingType = 56;
  
  // Reserved: 57-59 for future health persistence types

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTRY HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// All registered TypeIds with their model names.
  /// Used by SchemaValidator to verify adapter registration.
  static const Map<int, String> registry = {
    // Home Automation (0-9)
    roomHive: 'RoomModelHiveAdapter',
    deviceHive: 'DeviceModelHiveAdapter',
    
    // Persistence Core (10-19)
    room: 'RoomAdapter',
    pendingOp: 'PendingOpAdapter',
    device: 'DeviceModelAdapter',
    vitals: 'VitalsAdapter',
    userProfile: 'UserProfileModelAdapter',
    session: 'SessionModelAdapter',
    failedOp: 'FailedOpModelAdapter',
    auditLogRecord: 'AuditLogRecordAdapter',
    settings: 'SettingsModelAdapter',
    assetsCache: 'AssetsCacheEntryAdapter',
    
    // Sync & Failure (20-29)
    syncFailure: 'SyncFailureAdapter',
    syncFailureStatus: 'SyncFailureStatusAdapter',
    syncFailureSeverity: 'SyncFailureSeverityAdapter',
    
    // Services (30-39)
    transactionRecord: 'TransactionRecordAdapter',
    lockRecord: 'LockRecordAdapter',
    auditLogEntry: 'AuditLogEntryAdapter',
    auditLogArchive: 'AuditLogArchiveAdapter',
    
    // Onboarding & User Tables (40-46)
    userBase: 'UserBaseAdapter',
    caregiverUser: 'CaregiverUserAdapter',
    caregiverDetails: 'CaregiverDetailsAdapter',
    patientUser: 'PatientUserAdapter',
    patientDetails: 'PatientDetailsAdapter',
    relationship: 'RelationshipAdapter',
    relationshipStatus: 'RelationshipStatusAdapter',
    
    // Chat System (47-50)
    chatThread: 'ChatThreadAdapter',
    chatMessage: 'ChatMessageAdapter',
    chatMessageType: 'ChatMessageTypeAdapter',
    chatMessageLocalStatus: 'ChatMessageLocalStatusAdapter',
    
    // Doctor Role (51-52)
    doctorUser: 'DoctorUserAdapter',
    doctorDetails: 'DoctorDetailsAdapter',
    
    // Doctor-Patient Relationships (53-54)
    doctorRelationship: 'DoctorRelationshipAdapter',
    doctorRelationshipStatus: 'DoctorRelationshipStatusAdapter',
    
    // Health Data Persistence (55-59)
    storedHealthReading: 'StoredHealthReadingAdapter',
    storedHealthReadingType: 'StoredHealthReadingTypeAdapter',
  };
  
  /// Returns all TypeId values as a set.
  static Set<int> get allIds => registry.keys.toSet();
  
  /// Returns the adapter name for a given TypeId.
  static String? getAdapterName(int typeId) => registry[typeId];
  
  /// Checks if a TypeId is registered.
  static bool isRegistered(int typeId) => registry.containsKey(typeId);
  
  /// Returns the next available TypeId in a range.
  static int nextAvailableIn(int rangeStart, int rangeEnd) {
    for (int id = rangeStart; id <= rangeEnd; id++) {
      if (!registry.containsKey(id)) return id;
    }
    throw StateError('No available TypeId in range $rangeStart-$rangeEnd');
  }
}
