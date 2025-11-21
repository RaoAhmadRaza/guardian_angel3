import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Wrapper for biometric authentication. Abstracts local_auth for testability.
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometrics.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticate with biometrics or device credentials.
  /// Returns true if successful.
  Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) return false;
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle authentication error gracefully
      print('Biometric auth failed: ${e.message}');
      return false;
    }
  }

  /// Get available biometric types (e.g., face, fingerprint).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }
}
