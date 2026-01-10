/// Push Notification Sender — Sends FCM push notifications via Firebase Functions
///
/// This service sends push notifications by calling a Firebase Cloud Function.
/// The Cloud Function handles the actual FCM send operation server-side.
///
/// USAGE:
/// ```dart
/// await PushNotificationSender.instance.sendChatNotification(
///   recipientUid: 'user123',
///   senderName: 'John',
///   messagePreview: 'Hello!',
///   threadId: 'thread456',
/// );
/// ```
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Result of a push notification send operation
class PushSendResult {
  final bool success;
  final int? successCount;
  final int? failureCount;
  final String? error;

  const PushSendResult({
    required this.success,
    this.successCount,
    this.failureCount,
    this.error,
  });

  factory PushSendResult.success({int successCount = 1, int failureCount = 0}) =>
      PushSendResult(
        success: true,
        successCount: successCount,
        failureCount: failureCount,
      );

  factory PushSendResult.failure(String error) =>
      PushSendResult(success: false, error: error);
}

/// Push Notification Sender singleton
class PushNotificationSender {
  PushNotificationSender._();

  static final PushNotificationSender _instance = PushNotificationSender._();
  static PushNotificationSender get instance => _instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a chat message notification
  Future<PushSendResult> sendChatNotification({
    required String recipientUid,
    required String senderName,
    required String messagePreview,
    required String threadId,
    String? messageId,
  }) async {
    debugPrint('[PushNotificationSender] Sending chat notification to: $recipientUid');

    try {
      final callable = _functions.httpsCallable('sendChatNotification');
      final result = await callable.call<Map<String, dynamic>>({
        'recipient_uid': recipientUid,
        'sender_name': senderName,
        'message_preview': _truncateMessage(messagePreview),
        'thread_id': threadId,
        'message_id': messageId,
        'type': 'chat',
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;
      
      if (success) {
        debugPrint('[PushNotificationSender] Chat notification sent successfully');
        return PushSendResult.success(
          successCount: data['success_count'] as int? ?? 1,
          failureCount: data['failure_count'] as int? ?? 0,
        );
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        debugPrint('[PushNotificationSender] Chat notification failed: $error');
        return PushSendResult.failure(error);
      }
    } catch (e) {
      debugPrint('[PushNotificationSender] Chat notification error: $e');
      return PushSendResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOS ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send SOS alert to all linked caregivers and doctors
  Future<PushSendResult> sendSosAlert({
    required String patientUid,
    required String patientName,
    required String sosSessionId,
    required List<String> recipientUids,
    String? location,
    String? emergencyMessage,
  }) async {
    debugPrint('[PushNotificationSender] Sending SOS alert to ${recipientUids.length} recipients');

    if (recipientUids.isEmpty) {
      return PushSendResult.failure('No recipients provided');
    }

    try {
      final callable = _functions.httpsCallable('sendSosAlert');
      final result = await callable.call<Map<String, dynamic>>({
        'patient_uid': patientUid,
        'patient_name': patientName,
        'sos_session_id': sosSessionId,
        'recipient_uids': recipientUids,
        'location': location,
        'emergency_message': emergencyMessage,
        'type': 'sos_alert',
        'priority': 'high',
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;

      if (success) {
        debugPrint('[PushNotificationSender] SOS alert sent successfully');
        return PushSendResult.success(
          successCount: data['success_count'] as int? ?? recipientUids.length,
          failureCount: data['failure_count'] as int? ?? 0,
        );
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        debugPrint('[PushNotificationSender] SOS alert failed: $error');
        return PushSendResult.failure(error);
      }
    } catch (e) {
      debugPrint('[PushNotificationSender] SOS alert error: $e');
      return PushSendResult.failure(e.toString());
    }
  }

  /// Send SOS response notification (caregiver/doctor responded)
  Future<PushSendResult> sendSosResponseNotification({
    required String patientUid,
    required String responderUid,
    required String responderName,
    required String responderRole, // 'caregiver' or 'doctor'
    required String sosSessionId,
    required String responseType, // 'acknowledged', 'on_my_way', 'calling'
  }) async {
    debugPrint('[PushNotificationSender] Sending SOS response notification');

    try {
      final callable = _functions.httpsCallable('sendSosResponse');
      final result = await callable.call<Map<String, dynamic>>({
        'patient_uid': patientUid,
        'responder_uid': responderUid,
        'responder_name': responderName,
        'responder_role': responderRole,
        'sos_session_id': sosSessionId,
        'response_type': responseType,
        'type': responderRole == 'doctor' ? 'doctor_response' : 'caregiver_response',
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;

      if (success) {
        debugPrint('[PushNotificationSender] SOS response notification sent');
        return PushSendResult.success();
      } else {
        return PushSendResult.failure(data['error'] as String? ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('[PushNotificationSender] SOS response error: $e');
      return PushSendResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send health alert (arrhythmia detected, abnormal vitals, etc.)
  Future<PushSendResult> sendHealthAlert({
    required String patientUid,
    required String patientName,
    required String alertType, // 'arrhythmia', 'high_heart_rate', 'low_oxygen', etc.
    required String alertMessage,
    required List<String> recipientUids,
    String? alertId,
    Map<String, dynamic>? alertData,
  }) async {
    debugPrint('[PushNotificationSender] Sending health alert: $alertType');

    if (recipientUids.isEmpty) {
      return PushSendResult.failure('No recipients provided');
    }

    try {
      final callable = _functions.httpsCallable('sendHealthAlert');
      final result = await callable.call<Map<String, dynamic>>({
        'patient_uid': patientUid,
        'patient_name': patientName,
        'alert_type': alertType,
        'alert_message': alertMessage,
        'recipient_uids': recipientUids,
        'alert_id': alertId,
        'alert_data': alertData,
        'type': 'health_alert',
        'priority': alertType == 'arrhythmia' ? 'high' : 'normal',
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;

      if (success) {
        debugPrint('[PushNotificationSender] Health alert sent successfully');
        return PushSendResult.success(
          successCount: data['success_count'] as int? ?? recipientUids.length,
          failureCount: data['failure_count'] as int? ?? 0,
        );
      } else {
        return PushSendResult.failure(data['error'] as String? ?? 'Unknown error');
      }
    } catch (e) {
      debugPrint('[PushNotificationSender] Health alert error: $e');
      return PushSendResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Truncate message preview for notification body
  String _truncateMessage(String message, {int maxLength = 100}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength - 3)}...';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMS VIA CLOUD FUNCTION (TWILIO)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send SOS SMS to emergency contacts via Cloud Function (Twilio)
  /// This automatically sends SMS without user interaction
  Future<SmsSendResult> sendSosSms({
    required String patientUid,
    required String patientName,
    required String sosSessionId,
    required List<Map<String, dynamic>> contacts,
    String? location,
    String? emergencyMessage,
  }) async {
    debugPrint('[PushNotificationSender] Sending SOS SMS to ${contacts.length} contacts');

    if (contacts.isEmpty) {
      return SmsSendResult.failure('No contacts provided');
    }

    try {
      final callable = _functions.httpsCallable('sendSosSms');
      final result = await callable.call<Map<String, dynamic>>({
        'patient_uid': patientUid,
        'patient_name': patientName,
        'sos_session_id': sosSessionId,
        'contacts': contacts,
        'location': location,
        'emergency_message': emergencyMessage,
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;
      final twilioConfigured = data['twilio_configured'] as bool? ?? false;

      debugPrint('[PushNotificationSender] SMS result: success=$success, twilio_configured=$twilioConfigured');

      return SmsSendResult(
        success: success,
        successCount: data['success_count'] as int? ?? 0,
        failureCount: data['failure_count'] as int? ?? 0,
        twilioConfigured: twilioConfigured,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('[PushNotificationSender] SMS error: $e');
      return SmsSendResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMERGENCY CALL VIA CLOUD FUNCTION (TWILIO)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Place emergency call via Cloud Function (Twilio)
  /// This automatically places a call without user interaction
  Future<CallSendResult> sendSosCall({
    required String patientUid,
    required String patientName,
    required String sosSessionId,
    required String emergencyNumber,
    String? location,
  }) async {
    debugPrint('[PushNotificationSender] Placing emergency call to: $emergencyNumber');

    try {
      final callable = _functions.httpsCallable('sendSosCall');
      final result = await callable.call<Map<String, dynamic>>({
        'patient_uid': patientUid,
        'patient_name': patientName,
        'sos_session_id': sosSessionId,
        'emergency_number': emergencyNumber,
        'location': location,
      });

      final data = result.data;
      final success = data['success'] as bool? ?? false;
      final twilioConfigured = data['twilio_configured'] as bool? ?? false;

      debugPrint('[PushNotificationSender] Call result: success=$success, twilio_configured=$twilioConfigured');

      return CallSendResult(
        success: success,
        callSid: data['call_sid'] as String?,
        number: emergencyNumber,
        twilioConfigured: twilioConfigured,
        simulated: data['simulated'] as bool? ?? false,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('[PushNotificationSender] Call error: $e');
      return CallSendResult.failure(e.toString());
    }
  }
}

/// Result of an SMS send operation via Cloud Function
class SmsSendResult {
  final bool success;
  final int successCount;
  final int failureCount;
  final bool twilioConfigured;
  final String? error;

  const SmsSendResult({
    required this.success,
    this.successCount = 0,
    this.failureCount = 0,
    this.twilioConfigured = false,
    this.error,
  });

  factory SmsSendResult.failure(String error) => SmsSendResult(
        success: false,
        error: error,
      );
}

/// Result of an emergency call via Cloud Function
class CallSendResult {
  final bool success;
  final String? callSid;
  final String number;
  final bool twilioConfigured;
  final bool simulated;
  final String? error;

  const CallSendResult({
    required this.success,
    this.callSid,
    this.number = '',
    this.twilioConfigured = false,
    this.simulated = false,
    this.error,
  });

  factory CallSendResult.failure(String error) => CallSendResult(
        success: false,
        error: error,
      );
}
