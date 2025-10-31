import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _sessionKey = 'user_session_timestamp';
  static const String _loginStatusKey = 'user_logged_in';
  static const String _userTypeKey = 'user_type';
  static const int _sessionDurationDays = 2;

  static SessionService? _instance;

  static SessionService get instance {
    _instance ??= SessionService._internal();
    return _instance!;
  }

  SessionService._internal();

  /// Check if user has a valid session
  Future<bool> hasValidSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user is logged in
      final isLoggedIn = prefs.getBool(_loginStatusKey) ?? false;
      if (!isLoggedIn) {
        print('🔐 SessionService: User not logged in');
        return false;
      }

      // Check session timestamp
      final sessionTimestamp = prefs.getInt(_sessionKey);
      if (sessionTimestamp == null) {
        print('⏰ SessionService: No session timestamp found');
        return false;
      }

      final sessionDate = DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);
      final currentDate = DateTime.now();
      final daysDifference = currentDate.difference(sessionDate).inDays;

      final isValid = daysDifference < _sessionDurationDays;

      print('📅 SessionService: Session created: $sessionDate');
      print('📅 SessionService: Current time: $currentDate');
      print('📊 SessionService: Days difference: $daysDifference');
      print('✅ SessionService: Session valid: $isValid');

      return isValid;
    } catch (e) {
      print('❌ SessionService Error checking session: $e');
      return false;
    }
  }

  /// Start a new user session
  Future<void> startSession({String userType = 'patient'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setInt(_sessionKey, currentTimestamp);
      await prefs.setBool(_loginStatusKey, true);
      await prefs.setString(_userTypeKey, userType);

      print(
          '🎉 SessionService: New session started at ${DateTime.now()} for $userType');
    } catch (e) {
      print('❌ SessionService Error starting session: $e');
    }
  }

  /// End the current session (logout)
  Future<void> endSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_sessionKey);
      await prefs.setBool(_loginStatusKey, false);
      await prefs.remove(_userTypeKey);

      print('👋 SessionService: Session ended');
    } catch (e) {
      print('❌ SessionService Error ending session: $e');
    }
  }

  /// Get the current user type (patient/caregiver)
  Future<String?> getUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString(_userTypeKey);
      print('👤 SessionService: User type: $userType');
      return userType;
    } catch (e) {
      print('❌ SessionService Error getting user type: $e');
      return null;
    }
  }

  /// Reset session (for debug purposes)
  Future<void> resetSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_sessionKey);
      await prefs.remove(_loginStatusKey);
      await prefs.remove(_userTypeKey);

      print('🔄 SessionService: Session reset (debug)');
    } catch (e) {
      print('❌ SessionService Error resetting session: $e');
    }
  }

  /// Get session debug info
  Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool(_loginStatusKey) ?? false;
      final sessionTimestamp = prefs.getInt(_sessionKey);
      final userType = prefs.getString(_userTypeKey) ?? 'unknown';

      String sessionDateStr = 'No session';
      int daysSinceSession = 0;

      if (sessionTimestamp != null) {
        final sessionDate =
            DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);
        sessionDateStr = sessionDate.toString();
        daysSinceSession = DateTime.now().difference(sessionDate).inDays;
      }

      return {
        'isLoggedIn': isLoggedIn,
        'sessionDate': sessionDateStr,
        'daysSinceSession': daysSinceSession,
        'sessionValid': await hasValidSession(),
        'userType': userType,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
