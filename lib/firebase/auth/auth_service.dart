/// Firebase Authentication Service
/// 
/// Provides a clean abstraction layer over Firebase Auth.
/// All authentication calls in the app should go through this service.
/// 
/// This service:
/// - Exposes the current user
/// - Exposes auth state changes stream
/// - Provides sign-in and sign-out methods
/// - Is provider-agnostic (supports adding Google, Apple, Phone later)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result of an authentication operation.
class AuthResult {
  final bool success;
  final User? user;
  final String? errorCode;
  final String? errorMessage;
  
  const AuthResult._({
    required this.success,
    this.user,
    this.errorCode,
    this.errorMessage,
  });
  
  factory AuthResult.success(User user) => AuthResult._(
    success: true,
    user: user,
  );
  
  factory AuthResult.failure({
    required String errorCode,
    required String errorMessage,
  }) => AuthResult._(
    success: false,
    errorCode: errorCode,
    errorMessage: errorMessage,
  );
}

/// Authentication service providing a clean abstraction over Firebase Auth.
/// 
/// Usage:
/// ```dart
/// final authService = AuthService.instance;
/// 
/// // Listen to auth state changes
/// authService.authStateChanges.listen((user) {
///   if (user != null) {
///     print('User signed in: ${user.uid}');
///   } else {
///     print('User signed out');
///   }
/// });
/// 
/// // Get current user
/// final user = authService.currentUser;
/// 
/// // Sign out
/// await authService.signOut();
/// ```
class AuthService {
  AuthService._();
  
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// The currently signed-in user, or null if not authenticated.
  User? get currentUser => _auth.currentUser;
  
  /// The UID of the currently signed-in user, or null if not authenticated.
  String? get currentUserId => _auth.currentUser?.uid;
  
  /// Whether a user is currently signed in.
  bool get isAuthenticated => _auth.currentUser != null;
  
  /// Stream of authentication state changes.
  /// 
  /// Emits the current user when auth state changes (sign in/out).
  /// Emits null when the user signs out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  /// Stream that emits on user changes (including token refresh).
  /// 
  /// More granular than [authStateChanges] - also fires on:
  /// - Token refresh
  /// - User profile updates
  Stream<User?> get userChanges => _auth.userChanges();
  
  /// Stream that emits on ID token changes.
  /// 
  /// Useful for backend authentication scenarios.
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CORE AUTHENTICATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Signs out the current user.
  /// 
  /// Returns [AuthResult] indicating success or failure.
  Future<AuthResult> signOut() async {
    try {
      debugPrint('[AuthService] Signing out user: ${currentUser?.uid}');
      await _auth.signOut();
      debugPrint('[AuthService] Sign out successful');
      return AuthResult.success(_auth.currentUser ?? User as User);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Sign out failed: ${e.code} - ${e.message}');
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Sign out failed',
      );
    } catch (e) {
      debugPrint('[AuthService] Sign out failed with unexpected error: $e');
      return AuthResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Signs in with an [AuthCredential].
  /// 
  /// This is the base method used by all authentication providers.
  /// Provider-specific methods (Google, Apple, Phone) will call this
  /// with the appropriate credential.
  Future<AuthResult> signInWithCredential(AuthCredential credential) async {
    try {
      debugPrint('[AuthService] Signing in with credential: ${credential.providerId}');
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        debugPrint('[AuthService] Sign in successful: ${user.uid}');
        return AuthResult.success(user);
      } else {
        debugPrint('[AuthService] Sign in failed: No user returned');
        return AuthResult.failure(
          errorCode: 'no-user',
          errorMessage: 'No user returned from sign in',
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Sign in failed: ${e.code} - ${e.message}');
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Sign in failed',
      );
    } catch (e) {
      debugPrint('[AuthService] Sign in failed with unexpected error: $e');
      return AuthResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // USER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Reloads the current user's data from Firebase.
  /// 
  /// Useful after profile updates to get fresh data.
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      debugPrint('[AuthService] User reloaded successfully');
    } catch (e) {
      debugPrint('[AuthService] Failed to reload user: $e');
    }
  }
  
  /// Gets the current user's ID token.
  /// 
  /// Useful for authenticating with backend services.
  /// Set [forceRefresh] to true to get a fresh token.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final token = await _auth.currentUser?.getIdToken(forceRefresh);
      return token;
    } catch (e) {
      debugPrint('[AuthService] Failed to get ID token: $e');
      return null;
    }
  }
  
  /// Deletes the current user account.
  /// 
  /// This is a destructive operation and cannot be undone.
  /// The user may need to re-authenticate before this operation.
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(
          errorCode: 'no-user',
          errorMessage: 'No user is currently signed in',
        );
      }
      
      debugPrint('[AuthService] Deleting user account: ${user.uid}');
      await user.delete();
      debugPrint('[AuthService] Account deleted successfully');
      
      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Account deletion failed: ${e.code} - ${e.message}');
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: e.message ?? 'Account deletion failed',
      );
    } catch (e) {
      debugPrint('[AuthService] Account deletion failed with unexpected error: $e');
      return AuthResult.failure(
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }
}
