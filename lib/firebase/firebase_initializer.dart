/// Firebase Initialization Module
/// 
/// This file handles all Firebase initialization logic.
/// Must be called once before the app runs, typically in main().
/// 
/// Usage:
/// ```dart
/// await FirebaseInitializer.initialize();
/// ```

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// Singleton class responsible for Firebase initialization.
/// 
/// Ensures Firebase is initialized only once and provides
/// status information about the initialization state.
class FirebaseInitializer {
  FirebaseInitializer._();
  
  static final FirebaseInitializer _instance = FirebaseInitializer._();
  static FirebaseInitializer get instance => _instance;
  
  bool _isInitialized = false;
  FirebaseApp? _app;
  
  /// Returns true if Firebase has been successfully initialized.
  bool get isInitialized => _isInitialized;
  
  /// Returns the Firebase app instance if initialized.
  FirebaseApp? get app => _app;
  
  /// Initializes Firebase for the current platform.
  /// 
  /// This method is idempotent - calling it multiple times is safe.
  /// Returns the [FirebaseApp] instance on success.
  /// 
  /// Throws [FirebaseInitializationException] if initialization fails.
  static Future<FirebaseApp> initialize() async {
    if (_instance._isInitialized && _instance._app != null) {
      debugPrint('[FirebaseInitializer] Already initialized, skipping...');
      return _instance._app!;
    }
    
    try {
      debugPrint('[FirebaseInitializer] Initializing Firebase...');
      
      // Check if Firebase is already initialized at the native level
      if (Firebase.apps.isNotEmpty) {
        debugPrint('[FirebaseInitializer] Firebase already initialized at native level');
        _instance._app = Firebase.app();
        _instance._isInitialized = true;
        debugPrint('[FirebaseInitializer] Using existing app: ${_instance._app!.name}');
        return _instance._app!;
      }
      
      // Initialize Firebase with platform-specific options
      // Note: firebase_options.dart must be generated using `flutterfire configure`
      _instance._app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _instance._isInitialized = true;
      
      debugPrint('[FirebaseInitializer] Firebase initialized successfully');
      debugPrint('[FirebaseInitializer] App name: ${_instance._app!.name}');
      debugPrint('[FirebaseInitializer] Project ID: ${_instance._app!.options.projectId}');
      
      return _instance._app!;
    } catch (e, stackTrace) {
      debugPrint('[FirebaseInitializer] Failed to initialize Firebase: $e');
      debugPrint('[FirebaseInitializer] Stack trace: $stackTrace');
      
      throw FirebaseInitializationException(
        message: 'Failed to initialize Firebase',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Resets the initialization state (primarily for testing).
  @visibleForTesting
  static void reset() {
    _instance._isInitialized = false;
    _instance._app = null;
  }
}

/// Exception thrown when Firebase initialization fails.
class FirebaseInitializationException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  
  const FirebaseInitializationException({
    required this.message,
    this.cause,
    this.stackTrace,
  });
  
  @override
  String toString() => 'FirebaseInitializationException: $message (cause: $cause)';
}
