/// Apple Authentication Provider
/// 
/// Implements Apple Sign-In for Firebase Authentication.
/// Uses the sign_in_with_apple package for native sign-in flow.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_service.dart';
import 'auth_providers.dart' as local_auth;

/// Apple Sign-In authentication provider.
/// 
/// Usage:
/// ```dart
/// final appleProvider = AppleAuthProviderImpl.instance;
/// 
/// // Sign in with Apple
/// final result = await appleProvider.signInWithApple();
/// if (result.success) {
///   print('Signed in: ${result.user?.email}');
/// }
/// ```
class AppleAuthProviderImpl implements local_auth.AuthProvider {
  AppleAuthProviderImpl._();
  
  static final AppleAuthProviderImpl _instance = AppleAuthProviderImpl._();
  static AppleAuthProviderImpl get instance => _instance;
  
  @override
  local_auth.AuthProviderType get type => local_auth.AuthProviderType.apple;
  
  @override
  bool get isAvailable {
    // Apple Sign-In is available on iOS 13+ and macOS
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
  
  /// Generates a cryptographically secure random nonce.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Signs in with Apple and returns an [AuthCredential].
  /// 
  /// Returns null if the user cancels the sign-in flow.
  @override
  Future<AuthCredential?> signIn() async {
    try {
      debugPrint('[AppleAuthProvider] Starting Apple Sign-In flow...');
      
      // Generate a secure nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      
      // Request credentials from Apple
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      debugPrint('[AppleAuthProvider] Apple credential received');
      
      // Create an OAuthCredential from the Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      
      debugPrint('[AppleAuthProvider] OAuth credential created successfully');
      return oauthCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('[AppleAuthProvider] User cancelled sign-in');
        return null;
      }
      debugPrint('[AppleAuthProvider] Authorization error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[AppleAuthProvider] Sign-in failed: $e');
      return null;
    }
  }
  
  /// Signs in with Apple and authenticates with Firebase.
  /// 
  /// Returns an [AuthResult] with the user information on success.
  Future<AuthResult> signInWithApple() async {
    try {
      final credential = await signIn();
      
      if (credential == null) {
        return AuthResult(
          success: false,
          errorCode: 'cancelled',
          errorMessage: 'Apple sign-in was cancelled',
        );
      }
      
      // Sign in to Firebase with the Apple credential
      final userCredential = await AuthService.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        debugPrint('[AppleAuthProvider] Firebase sign-in successful: ${userCredential.user!.email}');
        return AuthResult(
          success: true,
          user: userCredential.user,
        );
      } else {
        return AuthResult(
          success: false,
          errorCode: 'no_user',
          errorMessage: 'Failed to get user after sign-in',
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AppleAuthProvider] Firebase auth error: ${e.code} - ${e.message}');
      return AuthResult(
        success: false,
        errorCode: e.code,
        errorMessage: e.message ?? 'Authentication failed',
      );
    } catch (e) {
      debugPrint('[AppleAuthProvider] Unexpected error: $e');
      return AuthResult(
        success: false,
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Signs out from Apple (clears any cached credentials).
  Future<void> signOut() async {
    // Apple Sign-In doesn't maintain a persistent session like Google,
    // but we can clear the Firebase auth state
    debugPrint('[AppleAuthProvider] Sign out called');
  }
}

/// Result of an Apple authentication attempt.
class AuthResult {
  final bool success;
  final User? user;
  final String? errorCode;
  final String? errorMessage;
  
  AuthResult({
    required this.success,
    this.user,
    this.errorCode,
    this.errorMessage,
  });
}
