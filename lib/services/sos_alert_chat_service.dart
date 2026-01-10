/// SOS Alert Chat Service — Sends emergency alert messages to chat threads.
///
/// When an SOS alert is triggered and not cancelled within 60 seconds,
/// this service sends an in-app chat message to all linked caregivers
/// and doctors with:
/// - Alert reason (manual trigger, fall detection, etc.)
/// - Patient's current vitals
/// - Location coordinates or map link
///
/// This integrates with the existing chat system WITHOUT modifying
/// the core chat models or services.
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../chat/services/chat_service.dart';
import '../chat/services/doctor_chat_service.dart';
import '../chat/models/chat_message_model.dart';
import '../chat/repositories/chat_repository_hive.dart';
import '../relationships/services/relationship_service.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../relationships/models/relationship_model.dart';
import '../relationships/models/doctor_relationship_model.dart';
import '../repositories/vitals_repository.dart';
import '../repositories/impl/vitals_repository_hive.dart';
import '../models/vitals_model.dart';

/// Alert trigger reasons
enum SosAlertReason {
  /// User manually triggered the SOS
  manual,
  
  /// Fall detection AI triggered the alert
  fallDetection,
  
  /// Arrhythmia detection (future)
  arrhythmia,
  
  /// Unknown or unspecified
  unknown,
}

extension SosAlertReasonExtension on SosAlertReason {
  String get displayName {
    switch (this) {
      case SosAlertReason.manual:
        return 'Manual SOS Trigger';
      case SosAlertReason.fallDetection:
        return '🚨 Fall Detected';
      case SosAlertReason.arrhythmia:
        return '❤️ Arrhythmia Alert';
      case SosAlertReason.unknown:
        return 'Emergency Alert';
    }
  }
  
  String get emoji {
    switch (this) {
      case SosAlertReason.manual:
        return '🆘';
      case SosAlertReason.fallDetection:
        return '🚨';
      case SosAlertReason.arrhythmia:
        return '❤️';
      case SosAlertReason.unknown:
        return '⚠️';
    }
  }
}

/// Result of sending SOS chat alerts
class SosAlertChatResult {
  final bool success;
  final int caregiverMessagesSent;
  final int doctorMessagesSent;
  final String? error;

  const SosAlertChatResult({
    required this.success,
    this.caregiverMessagesSent = 0,
    this.doctorMessagesSent = 0,
    this.error,
  });

  factory SosAlertChatResult.success({
    required int caregiverMessagesSent,
    required int doctorMessagesSent,
  }) =>
      SosAlertChatResult(
        success: true,
        caregiverMessagesSent: caregiverMessagesSent,
        doctorMessagesSent: doctorMessagesSent,
      );

  factory SosAlertChatResult.failure(String error) =>
      SosAlertChatResult(success: false, error: error);
}

/// Service for sending SOS alert messages to chat threads.
class SosAlertChatService {
  SosAlertChatService._();

  static final SosAlertChatService _instance = SosAlertChatService._();
  static SosAlertChatService get instance => _instance;

  final ChatRepositoryHive _chatRepository = ChatRepositoryHive();
  final RelationshipService _relationshipService = RelationshipService.instance;
  final DoctorRelationshipService _doctorRelationshipService = DoctorRelationshipService.instance;
  final VitalsRepository _vitalsRepository = VitalsRepositoryHive();
  final Uuid _uuid = const Uuid();
  
  // Firestore helper for mirroring messages so caregivers/doctors can receive them
  final _SosAlertFirestoreHelper _firestoreHelper = _SosAlertFirestoreHelper();

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND SOS ALERT TO ALL CHAT THREADS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends an SOS alert message to all linked caregivers and doctors.
  ///
  /// This is called when:
  /// 1. SOS is triggered and not cancelled within 60 seconds
  /// 2. Auto-escalation occurs
  ///
  /// The message includes:
  /// - Alert reason (why the alert was triggered)
  /// - Patient's current vitals (if available)
  /// - Location coordinates with Google Maps link
  Future<SosAlertChatResult> sendSosAlertToAllChats({
    required String patientUid,
    required String patientName,
    required SosAlertReason alertReason,
    Position? location,
    String? sosSessionId,
  }) async {
    debugPrint('[SosAlertChatService] Sending SOS alert to all chats');
    debugPrint('[SosAlertChatService] Patient: $patientUid, Reason: ${alertReason.displayName}');

    try {
      // Get patient's latest vitals
      final vitals = await _getLatestVitals(patientUid);

      // Build the alert message content
      final messageContent = _buildAlertMessage(
        patientName: patientName,
        alertReason: alertReason,
        location: location,
        vitals: vitals,
        sosSessionId: sosSessionId,
      );

      int caregiverCount = 0;
      int doctorCount = 0;

      // Send to all caregiver threads
      final caregiverResult = await _sendToCaregiverThreads(
        patientUid: patientUid,
        messageContent: messageContent,
      );
      caregiverCount = caregiverResult;

      // Send to all doctor threads
      final doctorResult = await _sendToDoctorThreads(
        patientUid: patientUid,
        messageContent: messageContent,
      );
      doctorCount = doctorResult;

      debugPrint('[SosAlertChatService] Sent to $caregiverCount caregivers, $doctorCount doctors');

      return SosAlertChatResult.success(
        caregiverMessagesSent: caregiverCount,
        doctorMessagesSent: doctorCount,
      );
    } catch (e) {
      debugPrint('[SosAlertChatService] Error sending SOS chat alerts: $e');
      return SosAlertChatResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND TO CAREGIVER THREADS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends the alert message to all caregiver chat threads.
  Future<int> _sendToCaregiverThreads({
    required String patientUid,
    required String messageContent,
  }) async {
    int sentCount = 0;

    try {
      // Get all relationships for the patient
      final relationshipResult = await _relationshipService.getRelationshipsForUser(patientUid);
      
      if (!relationshipResult.success || relationshipResult.data == null) {
        debugPrint('[SosAlertChatService] No caregiver relationships found');
        return 0;
      }

      // Filter active relationships with chat permission
      final activeRelationships = relationshipResult.data!.where(
        (r) => r.status == RelationshipStatus.active && 
               r.caregiverId != null &&
               r.caregiverId!.isNotEmpty,
      ).toList();

      debugPrint('[SosAlertChatService] Found ${activeRelationships.length} active caregiver relationships');

      for (final relationship in activeRelationships) {
        try {
          // Get or create the chat thread for this relationship
          final threadResult = await ChatService.instance.getOrCreateThreadForRelationship(
            relationshipId: relationship.id,
            patientId: relationship.patientId,
            caregiverId: relationship.caregiverId!,
          );

          if (!threadResult.success || threadResult.data == null) {
            debugPrint('[SosAlertChatService] Failed to get thread for relationship: ${relationship.id}');
            continue;
          }

          final thread = threadResult.data!;

          // Create and save the system message
          final message = ChatMessageModel(
            id: _uuid.v4(),
            threadId: thread.id,
            senderId: 'system', // System sender for automated alerts
            receiverId: relationship.caregiverId!,
            messageType: ChatMessageType.system,
            content: messageContent,
            localStatus: ChatMessageLocalStatus.sent,
            createdAt: DateTime.now().toUtc(),
            sentAt: DateTime.now().toUtc(),
            metadata: {
              'alert_type': 'sos_emergency',
              'automated': true,
            },
          );

          // Save to Hive (local first)
          final saveResult = await _chatRepository.saveMessage(message);
          
          if (saveResult.success) {
            sentCount++;
            debugPrint('[SosAlertChatService] Sent alert to caregiver: ${relationship.caregiverId}');
            
            // CRITICAL: Mirror to Firestore so caregiver receives the message
            // Without this, the message only exists in patient's local Hive
            await _firestoreHelper.mirrorMessage(message);
            debugPrint('[SosAlertChatService] Mirrored alert to Firestore for caregiver');
          }
        } catch (e) {
          debugPrint('[SosAlertChatService] Error sending to caregiver ${relationship.caregiverId}: $e');
        }
      }
    } catch (e) {
      debugPrint('[SosAlertChatService] Error in _sendToCaregiverThreads: $e');
    }

    return sentCount;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND TO DOCTOR THREADS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sends the alert message to all doctor chat threads.
  Future<int> _sendToDoctorThreads({
    required String patientUid,
    required String messageContent,
  }) async {
    int sentCount = 0;

    try {
      // Get all doctor relationships for the patient
      final relationshipResult = await _doctorRelationshipService.getRelationshipsForUser(patientUid);
      
      if (!relationshipResult.success || relationshipResult.data == null) {
        debugPrint('[SosAlertChatService] No doctor relationships found');
        return 0;
      }

      // Filter active relationships
      final activeRelationships = relationshipResult.data!.where(
        (r) => r.status == DoctorRelationshipStatus.active && 
               r.doctorId != null &&
               r.doctorId!.isNotEmpty,
      ).toList();

      debugPrint('[SosAlertChatService] Found ${activeRelationships.length} active doctor relationships');

      for (final relationship in activeRelationships) {
        try {
          // Get or create the doctor chat thread for this relationship
          final threadResult = await DoctorChatService.instance.getOrCreateDoctorThreadForRelationship(
            relationshipId: relationship.id,
            patientId: relationship.patientId,
            doctorId: relationship.doctorId!,
          );

          if (!threadResult.success || threadResult.data == null) {
            debugPrint('[SosAlertChatService] Failed to get doctor thread for relationship: ${relationship.id}');
            continue;
          }

          final thread = threadResult.data!;

          // Create and save the system message
          final message = ChatMessageModel(
            id: _uuid.v4(),
            threadId: thread.id,
            senderId: 'system', // System sender for automated alerts
            receiverId: relationship.doctorId!,
            messageType: ChatMessageType.system,
            content: messageContent,
            localStatus: ChatMessageLocalStatus.sent,
            createdAt: DateTime.now().toUtc(),
            sentAt: DateTime.now().toUtc(),
            metadata: {
              'alert_type': 'sos_emergency',
              'automated': true,
            },
          );

          // Save to Hive (local first)
          final saveResult = await _chatRepository.saveMessage(message);
          
          if (saveResult.success) {
            sentCount++;
            debugPrint('[SosAlertChatService] Sent alert to doctor: ${relationship.doctorId}');
            
            // CRITICAL: Mirror to Firestore so doctor receives the message
            // Without this, the message only exists in patient's local Hive
            await _firestoreHelper.mirrorMessage(message);
            debugPrint('[SosAlertChatService] Mirrored alert to Firestore for doctor');
          }
        } catch (e) {
          debugPrint('[SosAlertChatService] Error sending to doctor ${relationship.doctorId}: $e');
        }
      }
    } catch (e) {
      debugPrint('[SosAlertChatService] Error in _sendToDoctorThreads: $e');
    }

    return sentCount;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD ALERT MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Builds the formatted alert message with all relevant information.
  String _buildAlertMessage({
    required String patientName,
    required SosAlertReason alertReason,
    Position? location,
    VitalsModel? vitals,
    String? sosSessionId,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    // Header with emoji and reason
    buffer.writeln('${alertReason.emoji} EMERGENCY ALERT');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    
    // Alert reason
    buffer.writeln('⚡ Reason: ${alertReason.displayName}');
    buffer.writeln('👤 Patient: $patientName');
    buffer.writeln('🕐 Time: $timeStr on $dateStr');
    buffer.writeln();

    // Vitals section
    buffer.writeln('📊 VITALS AT TIME OF ALERT');
    buffer.writeln('─────────────────────');
    if (vitals != null) {
      buffer.writeln('❤️ Heart Rate: ${vitals.heartRate} bpm');
      buffer.writeln('🩸 Blood Pressure: ${vitals.systolicBp}/${vitals.diastolicBp} mmHg');
      if (vitals.oxygenPercent != null) {
        buffer.writeln('🫁 Oxygen: ${vitals.oxygenPercent}%');
      }
      if (vitals.temperatureC != null) {
        buffer.writeln('🌡️ Temperature: ${vitals.temperatureC!.toStringAsFixed(1)}°C');
      }
      if (vitals.stressIndex != null) {
        buffer.writeln('😰 Stress Index: ${vitals.stressIndex!.toStringAsFixed(0)}');
      }
    } else {
      buffer.writeln('⚠️ Vitals data unavailable');
    }
    buffer.writeln();

    // Location section
    buffer.writeln('📍 LOCATION');
    buffer.writeln('─────────────────────');
    if (location != null) {
      final lat = location.latitude.toStringAsFixed(6);
      final lon = location.longitude.toStringAsFixed(6);
      buffer.writeln('Coordinates: $lat, $lon');
      buffer.writeln('📱 Open in Maps:');
      buffer.writeln('https://maps.google.com/?q=${location.latitude},${location.longitude}');
    } else {
      buffer.writeln('⚠️ Location unavailable');
    }
    buffer.writeln();

    // Footer
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🚨 This is an automated emergency alert.');
    buffer.writeln('Please check on $patientName immediately.');
    
    if (sosSessionId != null) {
      buffer.writeln();
      buffer.writeln('Session ID: $sosSessionId');
    }

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET VITALS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gets the latest vitals for the patient.
  Future<VitalsModel?> _getLatestVitals(String patientUid) async {
    try {
      return await _vitalsRepository.getLatestForUser(patientUid);
    } catch (e) {
      debugPrint('[SosAlertChatService] Error getting vitals: $e');
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIRESTORE HELPER - Mirrors SOS alert messages to Firestore
// ═══════════════════════════════════════════════════════════════════════════════

/// Internal helper class to mirror SOS alert messages to Firestore.
/// 
/// This is CRITICAL for the caregiver to receive the alert message.
/// The patient's app saves to local Hive, but the caregiver's app
/// listens to Firestore for incoming messages. Without this mirror,
/// the caregiver would never see the SOS alert in their chat.
class _SosAlertFirestoreHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference for chat threads.
  CollectionReference<Map<String, dynamic>> get _threadsCollection =>
      _firestore.collection('chat_threads');

  /// Gets messages subcollection for a thread.
  CollectionReference<Map<String, dynamic>> _messagesCollection(String threadId) =>
      _threadsCollection.doc(threadId).collection('messages');

  /// Mirrors a message to Firestore.
  /// 
  /// NON-BLOCKING. Errors are logged but do not propagate.
  /// Uses set with merge to handle both create and update.
  Future<bool> mirrorMessage(ChatMessageModel message) async {
    debugPrint('[SosAlertFirestoreHelper] Mirroring SOS message: ${message.id}');

    try {
      // First ensure the thread exists in Firestore
      await _threadsCollection.doc(message.threadId).set(
        {
          'id': message.threadId,
          'last_message_at': FieldValue.serverTimestamp(),
          'server_updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Then save the message
      await _messagesCollection(message.threadId).doc(message.id).set(
        {
          ...message.toJson(),
          'server_created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      debugPrint('[SosAlertFirestoreHelper] SOS message mirrored successfully: ${message.id}');
      return true;
    } catch (e) {
      debugPrint('[SosAlertFirestoreHelper] Mirror failed: $e');
      // Do NOT rethrow - Firestore failures should not block the SOS flow
      return false;
    }
  }
}
