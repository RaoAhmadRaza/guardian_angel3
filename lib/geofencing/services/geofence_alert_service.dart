/// GeofenceAlertService - Sends geofence breach alerts to caregivers and doctors.
///
/// When a patient enters or exits a safe zone:
/// 1. Push notification is sent via FCM (using PushNotificationSender)
/// 2. In-app chat message is saved to all linked caregiver/doctor threads
///
/// Similar pattern to SosAlertChatService but for geofence events.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../chat/models/chat_message_model.dart';
import '../../chat/repositories/chat_repository_hive.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/services/doctor_chat_service.dart';
import '../../relationships/services/relationship_service.dart';
import '../../relationships/services/doctor_relationship_service.dart';
import '../../relationships/models/relationship_model.dart';
import '../../relationships/models/doctor_relationship_model.dart';
import '../models/safe_zone_model.dart';
import '../../services/push_notification_sender.dart';

/// Result of sending geofence alerts
class GeofenceAlertResult {
  final bool success;
  final int pushNotificationsSent;
  final int chatMessagesSent;
  final String? error;

  const GeofenceAlertResult({
    required this.success,
    this.pushNotificationsSent = 0,
    this.chatMessagesSent = 0,
    this.error,
  });

  factory GeofenceAlertResult.success({
    required int pushNotificationsSent,
    required int chatMessagesSent,
  }) =>
      GeofenceAlertResult(
        success: true,
        pushNotificationsSent: pushNotificationsSent,
        chatMessagesSent: chatMessagesSent,
      );

  factory GeofenceAlertResult.failure(String error) =>
      GeofenceAlertResult(success: false, error: error);
}

/// Service for sending geofence breach alerts.
class GeofenceAlertService {
  GeofenceAlertService._();

  static final GeofenceAlertService _instance = GeofenceAlertService._();
  static GeofenceAlertService get instance => _instance;

  final ChatRepositoryHive _chatRepository = ChatRepositoryHive();
  final RelationshipService _relationshipService = RelationshipService.instance;
  final DoctorRelationshipService _doctorRelationshipService = DoctorRelationshipService.instance;
  final PushNotificationSender _pushSender = PushNotificationSender.instance;
  final Uuid _uuid = const Uuid();

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND GEOFENCE ALERT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends a geofence alert to all linked caregivers and doctors.
  ///
  /// [zone] - The safe zone that was breached
  /// [event] - The geofence event (entry or exit)
  /// [latitude] - Current latitude
  /// [longitude] - Current longitude
  Future<GeofenceAlertResult> sendGeofenceAlert({
    required SafeZoneModel zone,
    required GeofenceEvent event,
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('[GeofenceAlertService] Sending geofence alert');
    debugPrint('[GeofenceAlertService] Zone: ${zone.name}, Event: ${event.eventType.displayName}');

    try {
      final patientUid = zone.patientUid;

      // Build the alert message
      final message = _buildAlertMessage(
        zone: zone,
        event: event,
        latitude: latitude,
        longitude: longitude,
      );

      // Collect recipient UIDs for push notifications
      final recipientUids = <String>[];

      // Get caregiver UIDs
      final caregiverResult = await _relationshipService.getRelationshipsForUser(patientUid);
      if (caregiverResult.success && caregiverResult.data != null) {
        for (final rel in caregiverResult.data!.where((r) => 
            r.status == RelationshipStatus.active && r.caregiverId != null)) {
          recipientUids.add(rel.caregiverId!);
        }
      }

      // Get doctor UIDs
      final doctorResult = await _doctorRelationshipService.getRelationshipsForUser(patientUid);
      if (doctorResult.success && doctorResult.data != null) {
        for (final rel in doctorResult.data!.where((r) =>
            r.status == DoctorRelationshipStatus.active && r.doctorId != null)) {
          recipientUids.add(rel.doctorId!);
        }
      }

      int pushCount = 0;
      int chatCount = 0;

      // Send push notifications
      if (recipientUids.isNotEmpty) {
        final pushResult = await _sendPushNotifications(
          patientUid: patientUid,
          zone: zone,
          event: event,
          recipientUids: recipientUids,
          latitude: latitude,
          longitude: longitude,
        );
        if (pushResult.success) {
          pushCount = pushResult.successCount ?? 0;
        }
      }

      // Send chat messages
      final caregiverCount = await _sendToCaregiverThreads(
        patientUid: patientUid,
        message: message,
      );
      final doctorCount = await _sendToDoctorThreads(
        patientUid: patientUid,
        message: message,
      );

      chatCount = caregiverCount + doctorCount;

      debugPrint('[GeofenceAlertService] Sent $pushCount push, $chatCount chat messages');

      return GeofenceAlertResult.success(
        pushNotificationsSent: pushCount,
        chatMessagesSent: chatCount,
      );
    } catch (e) {
      debugPrint('[GeofenceAlertService] Error sending geofence alert: $e');
      return GeofenceAlertResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUSH NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send push notifications to all linked caregivers and doctors
  Future<PushSendResult> _sendPushNotifications({
    required String patientUid,
    required SafeZoneModel zone,
    required GeofenceEvent event,
    required List<String> recipientUids,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final alertMessage = event.eventType == GeofenceEventType.exit
          ? 'Patient has left ${zone.name}'
          : 'Patient has entered ${zone.name}';

      // Use health alert function with geofence type
      return await _pushSender.sendHealthAlert(
        patientUid: patientUid,
        patientName: 'Patient', // Will be resolved server-side
        alertType: event.eventType == GeofenceEventType.exit 
            ? 'geofence_exit' 
            : 'geofence_entry',
        alertMessage: alertMessage,
        recipientUids: recipientUids,
        alertData: {
          'zone_id': zone.id,
          'zone_name': zone.name,
          'event_type': event.eventType.name,
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': event.timestamp.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[GeofenceAlertService] Push notification error: $e');
      return PushSendResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build the alert message with zone details and location
  String _buildAlertMessage({
    required SafeZoneModel zone,
    required GeofenceEvent event,
    required double latitude,
    required double longitude,
  }) {
    final buffer = StringBuffer();

    // Header with emoji
    if (event.eventType == GeofenceEventType.exit) {
      buffer.writeln('🚨 GEOFENCE ALERT');
      buffer.writeln('');
      buffer.writeln('Patient has LEFT a safe zone');
    } else {
      buffer.writeln('📍 GEOFENCE UPDATE');
      buffer.writeln('');
      buffer.writeln('Patient has ENTERED a safe zone');
    }

    buffer.writeln('');

    // Zone details
    buffer.writeln('📍 Zone: ${zone.name}');
    buffer.writeln('🏷️ Type: ${zone.type.displayName}');
    if (zone.address != null && zone.address!.isNotEmpty) {
      buffer.writeln('📮 Address: ${zone.address}');
    }

    buffer.writeln('');

    // Timestamp
    buffer.writeln('🕐 Time: ${_formatTimestamp(event.timestamp)}');

    buffer.writeln('');

    // Map link
    final mapLink = 'https://maps.google.com/maps?q=$latitude,$longitude';
    buffer.writeln('📌 Current Location:');
    buffer.writeln(mapLink);

    buffer.writeln('');

    // Action suggestion
    if (event.eventType == GeofenceEventType.exit) {
      buffer.writeln('⚠️ Please check on the patient or contact them.');
    }

    return buffer.toString();
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year $hour:$minute';
  }

  /// Send message to all caregiver chat threads
  Future<int> _sendToCaregiverThreads({
    required String patientUid,
    required String message,
  }) async {
    int count = 0;

    try {
      final result = await _relationshipService.getRelationshipsForUser(patientUid);
      
      if (!result.success || result.data == null || result.data!.isEmpty) {
        debugPrint('[GeofenceAlertService] No caregiver relationships found');
        return 0;
      }

      final activeRelationships = result.data!.where((rel) =>
          rel.status == RelationshipStatus.active &&
          rel.caregiverId != null &&
          rel.caregiverId!.isNotEmpty);

      debugPrint('[GeofenceAlertService] Found ${activeRelationships.length} active caregiver relationships');

      for (final relationship in activeRelationships) {
        try {
          // Get or create thread
          final threadResult = await ChatService.instance.getOrCreateThreadForRelationship(
            relationshipId: relationship.id,
            patientId: relationship.patientId,
            caregiverId: relationship.caregiverId!,
          );

          if (!threadResult.success || threadResult.data == null) {
            debugPrint('[GeofenceAlertService] Failed to get thread for relationship: ${relationship.id}');
            continue;
          }

          // Create system message
          final chatMessage = ChatMessageModel(
            id: _uuid.v4(),
            threadId: threadResult.data!.id,
            senderId: 'system',
            receiverId: relationship.caregiverId!,
            content: message,
            messageType: ChatMessageType.system,
            localStatus: ChatMessageLocalStatus.sent,
            createdAt: DateTime.now().toUtc(),
          );

          // Save to Hive
          await _chatRepository.saveMessage(chatMessage);
          count++;
          debugPrint('[GeofenceAlertService] Sent alert to caregiver: ${relationship.caregiverId}');
        } catch (e) {
          debugPrint('[GeofenceAlertService] Error sending to caregiver ${relationship.caregiverId}: $e');
        }
      }
    } catch (e) {
      debugPrint('[GeofenceAlertService] Error in _sendToCaregiverThreads: $e');
    }

    return count;
  }

  /// Send message to all doctor chat threads
  Future<int> _sendToDoctorThreads({
    required String patientUid,
    required String message,
  }) async {
    int count = 0;

    try {
      final result = await _doctorRelationshipService.getRelationshipsForUser(patientUid);

      if (!result.success || result.data == null || result.data!.isEmpty) {
        debugPrint('[GeofenceAlertService] No doctor relationships found');
        return 0;
      }

      final activeRelationships = result.data!.where((rel) =>
          rel.status == DoctorRelationshipStatus.active &&
          rel.doctorId != null &&
          rel.doctorId!.isNotEmpty);

      debugPrint('[GeofenceAlertService] Found ${activeRelationships.length} active doctor relationships');

      for (final relationship in activeRelationships) {
        try {
          // Get or create thread
          final threadResult = await DoctorChatService.instance.getOrCreateDoctorThreadForRelationship(
            relationshipId: relationship.id,
            patientId: relationship.patientId,
            doctorId: relationship.doctorId!,
          );

          if (!threadResult.success || threadResult.data == null) {
            debugPrint('[GeofenceAlertService] Failed to get doctor thread for relationship: ${relationship.id}');
            continue;
          }

          // Create system message
          final chatMessage = ChatMessageModel(
            id: _uuid.v4(),
            threadId: threadResult.data!.id,
            senderId: 'system',
            receiverId: relationship.doctorId!,
            content: message,
            messageType: ChatMessageType.system,
            localStatus: ChatMessageLocalStatus.sent,
            createdAt: DateTime.now().toUtc(),
          );

          // Save to Hive
          await _chatRepository.saveMessage(chatMessage);
          count++;
          debugPrint('[GeofenceAlertService] Sent alert to doctor: ${relationship.doctorId}');
        } catch (e) {
          debugPrint('[GeofenceAlertService] Error sending to doctor ${relationship.doctorId}: $e');
        }
      }
    } catch (e) {
      debugPrint('[GeofenceAlertService] Error in _sendToDoctorThreads: $e');
    }

    return count;
  }
}
