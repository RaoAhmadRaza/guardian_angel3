import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum for session state changes
enum SessionState {
  active,
  expired,
  loggedOut,
}

class SessionService {
  static const String _sessionKey = 'user_session_timestamp';
  static const String _loginStatusKey = 'user_logged_in';
  static const String _userTypeKey = 'user_type';
  static const String _userUidKey = 'current_user_uid';
  static const int _sessionDurationDays = 2;
  
  /// Stream controller for session state changes (Critical Issue #5)
  final _sessionStateController = StreamController<SessionState>.broadcast();
  
  /// Stream of session state changes for UI to listen to
  Stream<SessionState> get sessionStateStream => _sessionStateController.stream;
  
  /// Timer for periodic session validation
  Timer? _sessionCheckTimer;
  
  /// How often to check session validity (every 5 minutes)
  static const Duration _sessionCheckInterval = Duration(minutes: 5);

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLETON (DEPRECATED - Use Riverpod provider instead)
  // ═══════════════════════════════════════════════════════════════════════
  @Deprecated('Use sessionServiceProvider from service_providers.dart instead')
  static SessionService? _instance;
  @Deprecated('Use sessionServiceProvider from service_providers.dart instead')
  static SessionService get instance {
    _instance ??= SessionService._internal();
    return _instance!;
  }
  SessionService._internal();

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER DI CONSTRUCTOR (Use this via Riverpod)
  // ═══════════════════════════════════════════════════════════════════════
  /// Creates a new SessionService instance for dependency injection.
  SessionService();

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
      
      // Critical Issue #5: Broadcast session expiry if invalid
      if (!isValid) {
        _sessionStateController.add(SessionState.expired);
      }

      return isValid;
    } catch (e) {
      print('❌ SessionService Error checking session: $e');
      return false;
    }
  }
  
  /// Start periodic session validation checks
  /// Call this when app initializes or resumes from background
  void startSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(_sessionCheckInterval, (_) async {
      final isValid = await hasValidSession();
      if (!isValid) {
        _sessionStateController.add(SessionState.expired);
        _sessionCheckTimer?.cancel();
      }
    });
    print('⏰ SessionService: Started session monitoring');
  }
  
  /// Stop session monitoring
  void stopSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
    print('⏰ SessionService: Stopped session monitoring');
  }
  
  /// Get remaining session time in hours
  Future<int?> getRemainingSessionHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionTimestamp = prefs.getInt(_sessionKey);
      if (sessionTimestamp == null) return null;
      
      final sessionDate = DateTime.fromMillisecondsSinceEpoch(sessionTimestamp);
      final expiryDate = sessionDate.add(Duration(days: _sessionDurationDays));
      final remaining = expiryDate.difference(DateTime.now());
      
      return remaining.inHours;
    } catch (e) {
      return null;
    }
  }
  
  /// Check if session is about to expire (within 4 hours)
  Future<bool> isSessionAboutToExpire() async {
    final remaining = await getRemainingSessionHours();
    return remaining != null && remaining <= 4 && remaining > 0;
  }

  /// Start a new user session
  /// 
  /// [userType] is 'patient', 'caregiver', or 'doctor'
  /// [uid] is the Firebase Auth UID for the current user (REQUIRED for multi-user support)
  Future<void> startSession({String userType = 'patient', String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setInt(_sessionKey, currentTimestamp);
      await prefs.setBool(_loginStatusKey, true);
      await prefs.setString(_userTypeKey, userType);
      
      // Store the current user's UID - critical for multi-user support
      if (uid != null && uid.isNotEmpty) {
        await prefs.setString(_userUidKey, uid);
        print('👤 SessionService: Stored UID: $uid');
      }
      
      // Start session monitoring after login
      startSessionMonitoring();
      _sessionStateController.add(SessionState.active);

      print(
          '🎉 SessionService: New session started at ${DateTime.now()} for $userType (uid: $uid)');
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
      await prefs.remove(_userUidKey);
      
      // Stop monitoring and notify listeners
      stopSessionMonitoring();
      _sessionStateController.add(SessionState.loggedOut);

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

  /// Get the current user's UID from the session.
  /// 
  /// This is the CORRECT way to get the current user's UID when
  /// FirebaseAuth.instance.currentUser might be null (e.g., slow auth sync).
  /// Returns null if no session exists.
  Future<String?> getCurrentUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_userUidKey);
      print('👤 SessionService: Current UID: $uid');
      return uid;
    } catch (e) {
      print('❌ SessionService Error getting current UID: $e');
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
      await prefs.remove(_userUidKey);

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

      final uid = prefs.getString(_userUidKey) ?? 'not set';

      return {
        'isLoggedIn': isLoggedIn,
        'sessionDate': sessionDateStr,
        'daysSinceSession': daysSinceSession,
        'sessionValid': await hasValidSession(),
        'userType': userType,
        'uid': uid,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Dispose of resources (call when app is closing)
  void dispose() {
    stopSessionMonitoring();
    _sessionStateController.close();
  }
}
