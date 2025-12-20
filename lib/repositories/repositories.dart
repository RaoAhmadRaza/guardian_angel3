/// Repository Barrel Export
///
/// Part of PHASE 2: Backend is the only source of truth.
///
/// Import this file to access all repositories:
/// ```dart
/// import 'package:guardian_angel_fyp/repositories/repositories.dart';
/// ```
library;

// Abstract interfaces
export 'vitals_repository.dart';
export 'session_repository.dart';
export 'settings_repository.dart';
export 'audit_repository.dart';
export 'emergency_repository.dart';
export 'home_automation_repository.dart';
export 'user_profile_repository.dart';

// Hive implementations
export 'impl/vitals_repository_hive.dart';
export 'impl/session_repository_hive.dart';
export 'impl/settings_repository_hive.dart';
export 'impl/audit_repository_hive.dart';
export 'impl/emergency_repository_hive.dart';
export 'impl/home_automation_repository_hive.dart';
export 'impl/user_profile_repository_hive.dart';
