// test/mocks/mock_auth_service.dart
// Mock authentication service for testing

import 'package:guardian_angel_fyp/sync/auth_service.dart';

/// Mock authentication service for testing
/// Returns deterministic tokens without real authentication
class MockAuthService extends AuthService {
  String? _accessToken;
  String? _refreshToken;
  bool _shouldFailRefresh = false;

  MockAuthService({
    String? initialAccessToken,
    String? initialRefreshToken,
  })  : _accessToken = initialAccessToken ?? 'mock_access_token_123',
        _refreshToken = initialRefreshToken ?? 'mock_refresh_token_456';

  @override
  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  @override
  Future<bool> tryRefresh() async {
    if (_shouldFailRefresh) {
      return false;
    }
    
    // Simulate token refresh
    _accessToken = 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}';
    _refreshToken = 'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
    return true;
  }

  @override
  bool isAuthenticated() {
    return _accessToken != null;
  }

  @override
  void setAccessToken(String token) {
    _accessToken = token;
  }

  @override
  void setRefreshToken(String token) {
    _refreshToken = token;
  }

  /// Test helper: get refresh token
  String? getRefreshToken() {
    return _refreshToken;
  }

  /// Test helper: simulate refresh failure
  void setRefreshFailure(bool shouldFail) {
    _shouldFailRefresh = shouldFail;
  }

  @override
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }
}
