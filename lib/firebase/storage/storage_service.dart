/// Firebase Storage Service
/// 
/// Provides a clean abstraction layer over Firebase Storage.
/// All storage calls in the app should go through this service.
/// 
/// This service:
/// - Provides base reference setup
/// - Supports user-scoped storage paths
/// - Handles common error cases
/// - Is ready for upload/download logic to be added

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

/// Firebase Storage service providing reference management.
/// 
/// Usage:
/// ```dart
/// final storageService = StorageService.instance;
/// 
/// // Get a reference to a file
/// final imageRef = storageService.ref('images/photo.jpg');
/// 
/// // Get a reference in current user's folder
/// final userImageRef = storageService.userRef('profile.jpg');
/// 
/// // Get the root reference
/// final rootRef = storageService.root;
/// ```
class StorageService {
  StorageService._();
  
  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService.instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Configures Firebase Storage settings.
  /// 
  /// Should be called once during app initialization if custom settings needed.
  void configure({
    int maxUploadRetryTime = 600000, // 10 minutes in milliseconds
    int maxDownloadRetryTime = 600000,
    int maxOperationRetryTime = 120000, // 2 minutes
  }) {
    try {
      _storage.setMaxUploadRetryTime(Duration(milliseconds: maxUploadRetryTime));
      _storage.setMaxDownloadRetryTime(Duration(milliseconds: maxDownloadRetryTime));
      _storage.setMaxOperationRetryTime(Duration(milliseconds: maxOperationRetryTime));
      debugPrint('[StorageService] Configuration applied');
    } catch (e) {
      debugPrint('[StorageService] Configuration failed: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // REFERENCE ACCESS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns the root reference of the storage bucket.
  Reference get root => _storage.ref();
  
  /// Returns a reference to a file or folder at the specified path.
  /// 
  /// Example: `ref('images/photo.jpg')` returns a reference to that file.
  Reference ref(String path) {
    return _storage.ref(path);
  }
  
  /// Returns a reference from a Google Cloud Storage URI.
  /// 
  /// Example: `refFromURL('gs://bucket/path/to/file')`
  Reference refFromURL(String url) {
    return _storage.refFromURL(url);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // USER-SCOPED REFERENCES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns the current authenticated user's UID.
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  String get _requireUserId {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StorageAuthException('No authenticated user');
    }
    return userId;
  }
  
  /// Returns a reference to a file in the current user's storage folder.
  /// 
  /// Files are stored at: `users/{uid}/{path}`
  /// 
  /// Example: `userRef('profile.jpg')` returns `users/{uid}/profile.jpg`
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  Reference userRef(String path) {
    return _storage.ref('users/$_requireUserId/$path');
  }
  
  /// Returns a reference to the current user's root folder.
  /// 
  /// Example: `userRoot` returns `users/{uid}/`
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  Reference get userRoot {
    return _storage.ref('users/$_requireUserId');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // COMMON STORAGE PATHS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns a reference for storing profile images.
  /// 
  /// Path: `users/{uid}/profile/{filename}`
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  Reference profileImageRef(String filename) {
    return userRef('profile/$filename');
  }
  
  /// Returns a reference for storing media attachments.
  /// 
  /// Path: `users/{uid}/media/{filename}`
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  Reference mediaRef(String filename) {
    return userRef('media/$filename');
  }
  
  /// Returns a reference for storing documents.
  /// 
  /// Path: `users/{uid}/documents/{filename}`
  /// 
  /// Throws [StorageAuthException] if no user is authenticated.
  Reference documentRef(String filename) {
    return userRef('documents/$filename');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Generates a unique filename with timestamp.
  /// 
  /// Example: `generateFilename('jpg')` returns `1703123456789.jpg`
  String generateFilename(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp.$extension';
  }
  
  /// Generates a unique filename with prefix and timestamp.
  /// 
  /// Example: `generatePrefixedFilename('profile', 'jpg')` returns `profile_1703123456789.jpg`
  String generatePrefixedFilename(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp.$extension';
  }
  
  /// Returns the bucket name.
  String get bucket => _storage.bucket;
  
  /// Returns the maximum upload retry time in milliseconds.
  Duration get maxUploadRetryTime => _storage.maxUploadRetryTime;
  
  /// Returns the maximum download retry time in milliseconds.
  Duration get maxDownloadRetryTime => _storage.maxDownloadRetryTime;
  
  /// Returns the maximum operation retry time in milliseconds.
  Duration get maxOperationRetryTime => _storage.maxOperationRetryTime;
}

/// Exception thrown when a storage operation requires authentication
/// but no user is authenticated.
class StorageAuthException implements Exception {
  final String message;
  
  const StorageAuthException(this.message);
  
  @override
  String toString() => 'StorageAuthException: $message';
}
