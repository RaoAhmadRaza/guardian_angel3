/// Firestore Service
/// 
/// Provides a clean abstraction layer over Cloud Firestore.
/// All Firestore calls in the app should go through this service.
/// 
/// This service:
/// - Provides typed access to collections
/// - Uses the authenticated user UID when required
/// - Handles common error cases
/// - Supports offline persistence

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

/// Firestore service providing typed collection access.
/// 
/// Usage:
/// ```dart
/// final firestoreService = FirestoreService.instance;
/// 
/// // Access a collection
/// final usersRef = firestoreService.collection('users');
/// 
/// // Access current user's document
/// final userDoc = firestoreService.currentUserDocument('users');
/// 
/// // Access a subcollection under current user
/// final userPosts = firestoreService.currentUserSubcollection('users', 'posts');
/// ```
class FirestoreService {
  FirestoreService._();
  
  static final FirestoreService _instance = FirestoreService._();
  static FirestoreService get instance => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService.instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Configures Firestore settings.
  /// 
  /// Should be called once during app initialization.
  Future<void> configure({
    bool enablePersistence = true,
    bool enableLogging = false,
  }) async {
    try {
      if (enablePersistence) {
        _firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('[FirestoreService] Offline persistence enabled');
      }
      
      if (enableLogging && kDebugMode) {
        // Enable Firestore debug logging in debug mode
        debugPrint('[FirestoreService] Debug logging enabled');
      }
    } catch (e) {
      debugPrint('[FirestoreService] Configuration failed: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // COLLECTION ACCESS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns a reference to a top-level collection.
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }
  
  /// Returns a reference to a document.
  DocumentReference<Map<String, dynamic>> document(String path) {
    return _firestore.doc(path);
  }
  
  /// Returns a reference to a collection group.
  /// 
  /// Collection groups allow querying across all collections with the same ID.
  Query<Map<String, dynamic>> collectionGroup(String collectionId) {
    return _firestore.collectionGroup(collectionId);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // USER-SCOPED ACCESS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns the current authenticated user's UID.
  /// 
  /// Throws [FirestoreAuthException] if no user is authenticated.
  String get _requireUserId {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw FirestoreAuthException('No authenticated user');
    }
    return userId;
  }
  
  /// Returns a reference to the current user's document in a collection.
  /// 
  /// Example: `currentUserDocument('users')` returns `/users/{uid}`
  /// 
  /// Throws [FirestoreAuthException] if no user is authenticated.
  DocumentReference<Map<String, dynamic>> currentUserDocument(String collectionPath) {
    return _firestore.collection(collectionPath).doc(_requireUserId);
  }
  
  /// Returns a reference to a subcollection under the current user's document.
  /// 
  /// Example: `currentUserSubcollection('users', 'posts')` returns `/users/{uid}/posts`
  /// 
  /// Throws [FirestoreAuthException] if no user is authenticated.
  CollectionReference<Map<String, dynamic>> currentUserSubcollection(
    String parentCollection,
    String subcollection,
  ) {
    return _firestore
        .collection(parentCollection)
        .doc(_requireUserId)
        .collection(subcollection);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // TYPED COLLECTION REFERENCES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Creates a typed collection reference with custom converters.
  /// 
  /// Example:
  /// ```dart
  /// final usersRef = firestoreService.typedCollection<User>(
  ///   'users',
  ///   fromFirestore: (snapshot, _) => User.fromFirestore(snapshot),
  ///   toFirestore: (user, _) => user.toFirestore(),
  /// );
  /// ```
  CollectionReference<T> typedCollection<T>({
    required String path,
    required T Function(DocumentSnapshot<Map<String, dynamic>>, SnapshotOptions?) fromFirestore,
    required Map<String, Object?> Function(T, SetOptions?) toFirestore,
  }) {
    return _firestore.collection(path).withConverter<T>(
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH & TRANSACTION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Creates a new write batch.
  WriteBatch batch() {
    return _firestore.batch();
  }
  
  /// Runs a transaction.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    return _firestore.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Returns a server timestamp placeholder.
  /// 
  /// Use this when you want Firestore to set the server time.
  FieldValue get serverTimestamp => FieldValue.serverTimestamp();
  
  /// Returns a field value for incrementing a number.
  FieldValue increment(num value) => FieldValue.increment(value);
  
  /// Returns a field value for adding elements to an array.
  FieldValue arrayUnion(List<dynamic> elements) => FieldValue.arrayUnion(elements);
  
  /// Returns a field value for removing elements from an array.
  FieldValue arrayRemove(List<dynamic> elements) => FieldValue.arrayRemove(elements);
  
  /// Returns a field value for deleting a field.
  FieldValue get deleteField => FieldValue.delete();
  
  /// Clears all cached data.
  /// 
  /// Use with caution - this will clear offline data.
  Future<void> clearPersistence() async {
    try {
      await _firestore.clearPersistence();
      debugPrint('[FirestoreService] Persistence cleared');
    } catch (e) {
      debugPrint('[FirestoreService] Failed to clear persistence: $e');
    }
  }
  
  /// Terminates the Firestore instance.
  /// 
  /// After calling this, the instance cannot be used again.
  Future<void> terminate() async {
    try {
      await _firestore.terminate();
      debugPrint('[FirestoreService] Firestore terminated');
    } catch (e) {
      debugPrint('[FirestoreService] Failed to terminate: $e');
    }
  }
  
  /// Waits for pending writes to be acknowledged by the server.
  Future<void> waitForPendingWrites() async {
    try {
      await _firestore.waitForPendingWrites();
      debugPrint('[FirestoreService] Pending writes completed');
    } catch (e) {
      debugPrint('[FirestoreService] Failed to wait for pending writes: $e');
    }
  }
}

/// Exception thrown when a Firestore operation requires authentication
/// but no user is authenticated.
class FirestoreAuthException implements Exception {
  final String message;
  
  const FirestoreAuthException(this.message);
  
  @override
  String toString() => 'FirestoreAuthException: $message';
}
