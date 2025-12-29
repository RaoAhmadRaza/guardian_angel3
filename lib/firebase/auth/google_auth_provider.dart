/// Google Authentication Provider
/// 
/// Implements Google Sign-In for Firebase Authentication.
/// Uses the google_sign_in package for native sign-in flow.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';
import 'auth_providers.dart' as local_auth;

/// Google Sign-In authentication provider.
/// 
/// Usage:
/// ```dart
/// final googleProvider = GoogleAuthProvider.instance;
/// 
/// // Sign in with Google
/// final result = await googleProvider.signInWithGoogle();
/// if (result.success) {
///   print('Signed in: ${result.user?.email}');
/// }
/// ```
class GoogleAuthProviderImpl implements local_auth.AuthProvider {
  GoogleAuthProviderImpl._();
  
  static final GoogleAuthProviderImpl _instance = GoogleAuthProviderImpl._();
  static GoogleAuthProviderImpl get instance => _instance;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );
  
  @override
  local_auth.AuthProviderType get type => local_auth.AuthProviderType.google;
  
  @override
  bool get isAvailable {
    // Google Sign-In is available on iOS, Android, and Web
    return !kIsWeb || 
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }
  
  /// Signs in with Google and returns an [AuthCredential].
  /// 
  /// Returns null if the user cancels the sign-in flow.
  @override
  Future<AuthCredential?> signIn() async {
    try {
      debugPrint('[GoogleAuthProvider] Starting Google Sign-In flow...');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('[GoogleAuthProvider] User cancelled sign-in');
        return null;
      }
      
      debugPrint('[GoogleAuthProvider] Google user: ${googleUser.email}');
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      debugPrint('[GoogleAuthProvider] Credential created successfully');
      return credential;
    } catch (e) {
      debugPrint('[GoogleAuthProvider] Sign-in failed: $e');
      return null;
    }
  }
  
  /// Convenience method that signs in and authenticates with Firebase in one step.
  /// 
  /// Returns [AuthResult] with the signed-in user or error details.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final credential = await signIn();
      
      if (credential == null) {
        return AuthResult.failure(
          errorCode: 'cancelled',
          errorMessage: 'Google sign-in was cancelled',
        );
      }
      
      // Sign in to Firebase with the Google credential
      return await AuthService.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('[GoogleAuthProvider] Firebase sign-in failed: $e');
      return AuthResult.failure(
        errorCode: 'google-sign-in-failed',
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Signs out from Google.
  /// 
  /// Call this in addition to [AuthService.signOut] to fully sign out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('[GoogleAuthProvider] Signed out from Google');
    } catch (e) {
      debugPrint('[GoogleAuthProvider] Sign out failed: $e');
    }
  }
  
  /// Disconnects the Google account (revokes access).
  /// 
  /// Use this when the user wants to completely remove Google access.
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      debugPrint('[GoogleAuthProvider] Disconnected from Google');
    } catch (e) {
      debugPrint('[GoogleAuthProvider] Disconnect failed: $e');
    }
  }
  
  /// Returns the currently signed-in Google account, if any.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  
  /// Whether a Google account is currently signed in.
  bool get isSignedIn => _googleSignIn.currentUser != null;
}
