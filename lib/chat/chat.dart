/// Chat System - Central exports.
///
/// This is the public API for the chat system.
/// Import this file to access all chat functionality.
///
/// Architecture:
/// UI → ChatService → (validates relationship) → ChatRepositoryHive → Hive
///                                             → ChatFirestoreService → Firestore
///
/// SECURITY GUARANTEES:
/// 1. NO chat without active relationship
/// 2. NO chat without 'chat' permission  
/// 3. Local-first: Hive is source of truth
/// 4. Firestore is non-blocking mirror
library;

// Models
export 'models/chat_thread_model.dart';
export 'models/chat_message_model.dart';

// Repositories
export 'repositories/chat_repository.dart';
export 'repositories/chat_repository_hive.dart';

// Services
export 'services/chat_service.dart';
export 'services/chat_firestore_service.dart';

// Providers
export 'providers/chat_provider.dart';

// Screens
export 'screens/patient_caregiver_chat_screen.dart';
export 'screens/chat_threads_list_screen.dart';
