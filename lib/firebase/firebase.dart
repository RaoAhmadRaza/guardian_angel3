/// Firebase Module Exports
/// 
/// This barrel file exports all Firebase services for easy importing.
/// 
/// Usage:
/// ```dart
/// import 'package:guardian_angel_fyp/firebase/firebase.dart';
/// 
/// // Access services
/// final auth = AuthService.instance;
/// final firestore = FirestoreService.instance;
/// final storage = StorageService.instance;
/// ```

// Core
export 'firebase_initializer.dart';

// Authentication
export 'auth/auth_service.dart';
export 'auth/auth_providers.dart';
export 'auth/google_auth_provider.dart';

// Firestore
export 'firestore/firestore_service.dart';

// Storage
export 'storage/storage_service.dart';
