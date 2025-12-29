/// Authentication Providers Enum and Registry
/// 
/// Defines the supported authentication providers and provides
/// a registry pattern for adding new providers.
/// 
/// This file is provider-agnostic and ready for adding:
/// - Google Sign-In
/// - Apple Sign-In  
/// - Phone Authentication
/// - Email/Password (if needed)

import 'package:firebase_auth/firebase_auth.dart';

/// Supported authentication provider types.
enum AuthProviderType {
  /// Google Sign-In
  google,
  
  /// Apple Sign-In
  apple,
  
  /// Phone number authentication with SMS verification
  phone,
  
  /// Email and password authentication
  email,
  
  /// Anonymous authentication
  anonymous,
}

/// Extension to provide additional functionality for [AuthProviderType].
extension AuthProviderTypeExtension on AuthProviderType {
  /// Returns the Firebase provider ID for this provider type.
  String get providerId {
    switch (this) {
      case AuthProviderType.google:
        return GoogleAuthProvider.PROVIDER_ID;
      case AuthProviderType.apple:
        return 'apple.com';
      case AuthProviderType.phone:
        return PhoneAuthProvider.PROVIDER_ID;
      case AuthProviderType.email:
        return EmailAuthProvider.PROVIDER_ID;
      case AuthProviderType.anonymous:
        return 'anonymous';
    }
  }
  
  /// Returns a human-readable name for this provider.
  String get displayName {
    switch (this) {
      case AuthProviderType.google:
        return 'Google';
      case AuthProviderType.apple:
        return 'Apple';
      case AuthProviderType.phone:
        return 'Phone';
      case AuthProviderType.email:
        return 'Email';
      case AuthProviderType.anonymous:
        return 'Anonymous';
    }
  }
}

/// Abstract base class for authentication providers.
/// 
/// Each provider (Google, Apple, Phone) will extend this class
/// and implement the [signIn] method.
abstract class AuthProvider {
  /// The type of this provider.
  AuthProviderType get type;
  
  /// Initiates the sign-in flow for this provider.
  /// 
  /// Returns an [AuthCredential] that can be used with
  /// [AuthService.signInWithCredential].
  /// 
  /// Returns null if the user cancels or an error occurs.
  Future<AuthCredential?> signIn();
  
  /// Whether this provider is available on the current platform.
  bool get isAvailable;
}

/// Registry for managing authentication providers.
/// 
/// Providers can be registered and retrieved by type.
/// This allows for clean separation of provider implementations.
class AuthProviderRegistry {
  AuthProviderRegistry._();
  
  static final AuthProviderRegistry _instance = AuthProviderRegistry._();
  static AuthProviderRegistry get instance => _instance;
  
  final Map<AuthProviderType, AuthProvider> _providers = {};
  
  /// Registers an authentication provider.
  void register(AuthProvider provider) {
    _providers[provider.type] = provider;
  }
  
  /// Unregisters an authentication provider.
  void unregister(AuthProviderType type) {
    _providers.remove(type);
  }
  
  /// Gets a registered provider by type.
  /// 
  /// Returns null if the provider is not registered.
  AuthProvider? get(AuthProviderType type) => _providers[type];
  
  /// Returns all registered providers.
  List<AuthProvider> get allProviders => _providers.values.toList();
  
  /// Returns all available providers for the current platform.
  List<AuthProvider> get availableProviders => 
      _providers.values.where((p) => p.isAvailable).toList();
  
  /// Clears all registered providers.
  void clear() {
    _providers.clear();
  }
}
