/// FCM Service — Firebase Cloud Messaging Integration
///
/// Handles:
/// - FCM token registration and refresh
/// - Push notification permissions
/// - Foreground/background message handling
/// - Token storage in Firestore for delivery targeting
///
/// USAGE:
/// ```dart
/// await FCMService.instance.initialize();
/// final token = FCMService.instance.currentToken;
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Message: ${message.messageId}');
  // Handle background message - typically triggers local notification
}

/// Notification payload types
enum FCMNotificationType {
  chat,
  sosAlert,
  healthAlert,
  caregiverResponse,
  doctorResponse,
}

/// Parsed FCM notification data
class FCMNotificationData {
  final FCMNotificationType type;
  final String? senderId;
  final String? threadId;
  final String? sosSessionId;
  final String? alertId;
  final Map<String, dynamic> rawData;

  const FCMNotificationData({
    required this.type,
    this.senderId,
    this.threadId,
    this.sosSessionId,
    this.alertId,
    required this.rawData,
  });

  factory FCMNotificationData.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final typeString = data['type'] as String? ?? 'chat';
    
    FCMNotificationType type;
    switch (typeString) {
      case 'sos_alert':
        type = FCMNotificationType.sosAlert;
        break;
      case 'health_alert':
        type = FCMNotificationType.healthAlert;
        break;
      case 'caregiver_response':
        type = FCMNotificationType.caregiverResponse;
        break;
      case 'doctor_response':
        type = FCMNotificationType.doctorResponse;
        break;
      default:
        type = FCMNotificationType.chat;
    }

    return FCMNotificationData(
      type: type,
      senderId: data['sender_id'] as String?,
      threadId: data['thread_id'] as String?,
      sosSessionId: data['sos_session_id'] as String?,
      alertId: data['alert_id'] as String?,
      rawData: data,
    );
  }
}

/// FCM Service singleton
class FCMService {
  FCMService._();

  static final FCMService _instance = FCMService._();
  static FCMService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentToken;
  bool _initialized = false;

  /// Current FCM token
  String? get currentToken => _currentToken;

  /// Whether service is initialized
  bool get isInitialized => _initialized;

  /// Stream controller for incoming messages (foreground)
  final _messageController = StreamController<FCMNotificationData>.broadcast();
  Stream<FCMNotificationData> get onMessage => _messageController.stream;

  /// Stream controller for notification taps
  final _notificationTapController = StreamController<FCMNotificationData>.broadcast();
  Stream<FCMNotificationData> get onNotificationTap => _notificationTapController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize FCM service
  ///
  /// MUST be called after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[FCMService] Initializing...');

    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      final settings = await _requestPermissions();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCMService] Notifications permission denied');
        return;
      }

      // Get FCM token
      await _getAndStoreToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handle notification taps (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _onNotificationTap(initialMessage);
      }

      // Configure foreground presentation options (iOS)
      if (Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _initialized = true;
      debugPrint('[FCMService] Initialized successfully. Token: $_currentToken');
    } catch (e) {
      debugPrint('[FCMService] Initialization failed: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true, // For SOS alerts
      provisional: false,
      sound: true,
    );

    debugPrint('[FCMService] Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Get FCM token and store in Firestore
  Future<void> _getAndStoreToken() async {
    try {
      // For iOS, get APNS token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('[FCMService] APNS token not available yet');
          // Retry after delay
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      _currentToken = await _messaging.getToken();
      debugPrint('[FCMService] Got token: $_currentToken');

      if (_currentToken != null) {
        await _storeTokenInFirestore(_currentToken!);
      }
    } catch (e) {
      debugPrint('[FCMService] Failed to get token: $e');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('[FCMService] Token refreshed: $newToken');
    _currentToken = newToken;
    await _storeTokenInFirestore(newToken);
  }

  /// Store FCM token in Firestore for delivery targeting
  Future<void> _storeTokenInFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FCMService] No user logged in, cannot store token');
      return;
    }

    try {
      await _firestore.collection('users').doc(uid).set({
        'fcm_tokens': FieldValue.arrayUnion([
          {
            'token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'updated_at': FieldValue.serverTimestamp(),
          }
        ]),
        'last_token_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCMService] Token stored in Firestore for user: $uid');
    } catch (e) {
      debugPrint('[FCMService] Failed to store token: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle foreground messages
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCMService] Foreground message: ${message.messageId}');
    debugPrint('[FCMService] Data: ${message.data}');
    debugPrint('[FCMService] Notification: ${message.notification?.title}');

    final data = FCMNotificationData.fromRemoteMessage(message);
    _messageController.add(data);
  }

  /// Handle notification tap (app opened from notification)
  void _onNotificationTap(RemoteMessage message) {
    debugPrint('[FCMService] Notification tapped: ${message.messageId}');
    
    final data = FCMNotificationData.fromRemoteMessage(message);
    _notificationTapController.add(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API - TOKEN MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get FCM tokens for a specific user (for sending notifications)
  Future<List<String>> getTokensForUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null) return [];

      final tokens = data['fcm_tokens'] as List<dynamic>?;
      if (tokens == null) return [];

      return tokens
          .map((t) => (t as Map<String, dynamic>)['token'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      debugPrint('[FCMService] Failed to get tokens for user $uid: $e');
      return [];
    }
  }

  /// Remove current token (on logout)
  Future<void> removeToken() async {
    if (_currentToken == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcm_tokens': FieldValue.arrayRemove([
          {'token': _currentToken}
        ]),
      });
      debugPrint('[FCMService] Token removed from Firestore');
    } catch (e) {
      debugPrint('[FCMService] Failed to remove token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
    _notificationTapController.close();
  }
}
