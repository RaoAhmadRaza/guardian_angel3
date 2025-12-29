/// Firebase Phone Authentication Provider
/// 
/// Handles phone number verification via SMS using Firebase Auth.
/// Supports sending verification codes, verifying OTPs, and resending codes.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result class for phone verification operations
class PhoneVerificationResult {
  final bool success;
  final String? verificationId;
  final String? errorCode;
  final String? errorMessage;
  final User? user;

  PhoneVerificationResult({
    required this.success,
    this.verificationId,
    this.errorCode,
    this.errorMessage,
    this.user,
  });
}

/// Phone Authentication Provider using Firebase
class PhoneAuthProviderImpl {
  PhoneAuthProviderImpl._();
  
  static final PhoneAuthProviderImpl _instance = PhoneAuthProviderImpl._();
  static PhoneAuthProviderImpl get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;

  /// Sends a verification code to the provided phone number.
  /// 
  /// [phoneNumber] must be in E.164 format (e.g., +1234567890)
  Future<PhoneVerificationResult> sendVerificationCode(String phoneNumber) async {
    try {
      final completer = Completer<PhoneVerificationResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        
        // Called when verification is completed automatically (Android only)
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[PhoneAuth] Auto-verification completed');
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(PhoneVerificationResult(
                success: true,
                user: userCredential.user,
              ));
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(PhoneVerificationResult(
                success: false,
                errorMessage: 'Auto sign-in failed: $e',
              ));
            }
          }
        },
        
        // Called when verification fails
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[PhoneAuth] Verification failed: ${e.code} - ${e.message}');
          if (!completer.isCompleted) {
            completer.complete(PhoneVerificationResult(
              success: false,
              errorCode: e.code,
              errorMessage: _getErrorMessage(e.code),
            ));
          }
        },
        
        // Called when code is sent successfully
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[PhoneAuth] Code sent, verificationId: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(PhoneVerificationResult(
              success: true,
              verificationId: verificationId,
            ));
          }
        },
        
        // Called when the timeout expires
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[PhoneAuth] Auto retrieval timeout');
          _verificationId = verificationId;
        },
      );

      return await completer.future;
    } catch (e) {
      debugPrint('[PhoneAuth] Error sending code: $e');
      return PhoneVerificationResult(
        success: false,
        errorMessage: 'Failed to send verification code: $e',
      );
    }
  }

  /// Verifies the OTP code entered by the user.
  /// 
  /// [verificationId] is the ID received from sendVerificationCode
  /// [smsCode] is the 6-digit code entered by the user
  Future<PhoneVerificationResult> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      debugPrint('[PhoneAuth] OTP verified successfully');
      return PhoneVerificationResult(
        success: true,
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[PhoneAuth] OTP verification failed: ${e.code}');
      return PhoneVerificationResult(
        success: false,
        errorCode: e.code,
        errorMessage: _getErrorMessage(e.code),
      );
    } catch (e) {
      debugPrint('[PhoneAuth] OTP verification error: $e');
      return PhoneVerificationResult(
        success: false,
        errorMessage: 'Verification failed: $e',
      );
    }
  }

  /// Resends the verification code to the same phone number.
  Future<PhoneVerificationResult> resendVerificationCode(String phoneNumber) async {
    try {
      final completer = Completer<PhoneVerificationResult>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(PhoneVerificationResult(
                success: true,
                user: userCredential.user,
              ));
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(PhoneVerificationResult(
                success: false,
                errorMessage: 'Auto sign-in failed: $e',
              ));
            }
          }
        },
        
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.complete(PhoneVerificationResult(
              success: false,
              errorCode: e.code,
              errorMessage: _getErrorMessage(e.code),
            ));
          }
        },
        
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(PhoneVerificationResult(
              success: true,
              verificationId: verificationId,
            ));
          }
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return await completer.future;
    } catch (e) {
      return PhoneVerificationResult(
        success: false,
        errorMessage: 'Failed to resend code: $e',
      );
    }
  }

  /// Gets the current user if signed in
  User? get currentUser => _auth.currentUser;

  /// Signs out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Converts Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'app-not-authorized':
        return 'App not authorized for phone auth. Contact support.';
      case 'captcha-check-failed':
        return 'Security check failed. Please try again.';
      default:
        return 'Verification failed. Please try again.';
    }
  }
}

/// Completer helper for async callbacks
class Completer<T> {
  T? _value;
  bool _isCompleted = false;
  final List<void Function(T)> _callbacks = [];

  bool get isCompleted => _isCompleted;

  void complete(T value) {
    if (_isCompleted) return;
    _isCompleted = true;
    _value = value;
    for (final callback in _callbacks) {
      callback(value);
    }
  }

  Future<T> get future async {
    if (_isCompleted) return _value as T;
    
    final completer = _InternalCompleter<T>();
    _callbacks.add((value) => completer.complete(value));
    return completer.future;
  }
}

class _InternalCompleter<T> {
  final _future = _InternalFuture<T>();
  
  Future<T> get future => _future;
  
  void complete(T value) {
    _future._complete(value);
  }
}

class _InternalFuture<T> implements Future<T> {
  T? _value;
  bool _isCompleted = false;
  final List<void Function(T)> _callbacks = [];

  void _complete(T value) {
    _isCompleted = true;
    _value = value;
    for (final callback in _callbacks) {
      callback(value);
    }
  }

  @override
  Stream<T> asStream() => Stream.value(_value as T);

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) async {
    if (_isCompleted) {
      return onValue(_value as T);
    }
    
    final completer = _InternalCompleter<R>();
    _callbacks.add((value) async {
      final result = await onValue(value);
      completer.complete(result);
    });
    return completer.future;
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) => this;

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) async {
    if (_isCompleted) {
      await action();
      return _value as T;
    }
    _callbacks.add((value) async {
      await action();
    });
    return this;
  }
}
