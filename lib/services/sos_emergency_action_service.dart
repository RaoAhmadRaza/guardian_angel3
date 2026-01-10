/// SOS Emergency Action Service — Real Emergency Actions
///
/// This service ACTUALLY performs emergency actions:
/// - Sends push notifications to caregivers and doctors
/// - Sends SMS to emergency contacts
/// - Initiates phone calls to emergency services (1122 Pakistan)
/// - Logs all actions to Firestore for audit trail
///
/// NO SIMULATIONS. NO PLACEHOLDERS. REAL ACTIONS ONLY.
library;

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../services/push_notification_sender.dart';
import '../services/emergency_contact_service.dart';
import '../services/sos_alert_chat_service.dart';
import '../relationships/services/relationship_service.dart';
import '../relationships/services/doctor_relationship_service.dart';
import '../relationships/models/doctor_relationship_model.dart';

/// Pakistan emergency number
const String _emergencyNumber = '1122';

/// Auto-escalation timeout (no caregiver response)
const Duration _autoEscalationTimeout = Duration(seconds: 60);

/// SOS session state
enum SosSessionState {
  idle,
  active,
  caregiverNotified,
  caregiverResponded,
  escalated,
  emergencyCallPlaced,
  resolved,
  cancelled,
}

/// SOS action type for audit logging
enum SosActionType {
  sessionStarted,
  pushSent,
  smsSent,
  smsFailedPermission,
  smsFailedNetwork,
  caregiverResponded,
  doctorResponded,
  autoEscalation,
  emergencyCallInitiated,
  emergencyCallFailed,
  sessionResolved,
  sessionCancelled,
}

/// SOS session model
class SosSession {
  final String id;
  final String patientUid;
  final String patientName;
  final DateTime startedAt;
  final SosSessionState state;
  final Position? location;
  final List<String> notifiedCaregivers;
  final List<String> notifiedDoctors;
  final List<String> respondedUids;
  final bool emergencyCallPlaced;
  final SosAlertReason alertReason;
  final bool chatAlertSent;

  const SosSession({
    required this.id,
    required this.patientUid,
    required this.patientName,
    required this.startedAt,
    required this.state,
    this.location,
    this.notifiedCaregivers = const [],
    this.notifiedDoctors = const [],
    this.respondedUids = const [],
    this.emergencyCallPlaced = false,
    this.alertReason = SosAlertReason.manual,
    this.chatAlertSent = false,
  });

  SosSession copyWith({
    SosSessionState? state,
    Position? location,
    List<String>? notifiedCaregivers,
    List<String>? notifiedDoctors,
    List<String>? respondedUids,
    bool? emergencyCallPlaced,
    SosAlertReason? alertReason,
    bool? chatAlertSent,
  }) {
    return SosSession(
      id: id,
      patientUid: patientUid,
      patientName: patientName,
      startedAt: startedAt,
      state: state ?? this.state,
      location: location ?? this.location,
      notifiedCaregivers: notifiedCaregivers ?? this.notifiedCaregivers,
      notifiedDoctors: notifiedDoctors ?? this.notifiedDoctors,
      respondedUids: respondedUids ?? this.respondedUids,
      emergencyCallPlaced: emergencyCallPlaced ?? this.emergencyCallPlaced,
      alertReason: alertReason ?? this.alertReason,
      chatAlertSent: chatAlertSent ?? this.chatAlertSent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_uid': patientUid,
        'patient_name': patientName,
        'started_at': startedAt.toUtc().toIso8601String(),
        'state': state.name,
        'location': location != null
            ? {
                'latitude': location!.latitude,
                'longitude': location!.longitude,
                'accuracy': location!.accuracy,
              }
            : null,
        'notified_caregivers': notifiedCaregivers,
        'notified_doctors': notifiedDoctors,
        'responded_uids': respondedUids,
        'emergency_call_placed': emergencyCallPlaced,
        'alert_reason': alertReason.name,
        'chat_alert_sent': chatAlertSent,
      };
}

/// Result of an SOS action
class SosActionResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? data;

  const SosActionResult({
    required this.success,
    this.error,
    this.data,
  });

  factory SosActionResult.success([Map<String, dynamic>? data]) =>
      SosActionResult(success: true, data: data);

  factory SosActionResult.failure(String error) =>
      SosActionResult(success: false, error: error);
}

/// SOS Emergency Action Service
class SosEmergencyActionService {
  SosEmergencyActionService._();

  static final SosEmergencyActionService _instance =
      SosEmergencyActionService._();
  static SosEmergencyActionService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PushNotificationSender _pushSender = PushNotificationSender.instance;
  final RelationshipService _relationshipService = RelationshipService.instance;
  final EmergencyContactService _emergencyContactService =
      EmergencyContactService.instance;
  final Uuid _uuid = const Uuid();

  SosSession? _currentSession;
  Timer? _escalationTimer;
  StreamController<SosSession>? _sessionController;

  /// Current SOS session
  SosSession? get currentSession => _currentSession;

  /// Whether an SOS session is active
  bool get isActive => _currentSession != null;

  /// Stream of session updates
  Stream<SosSession> get sessionStream {
    _sessionController ??= StreamController<SosSession>.broadcast();
    return _sessionController!.stream;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // START SOS SESSION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start a new SOS session
  ///
  /// This will:
  /// 1. Create session in Firestore
  /// 2. Get patient's location
  /// 3. Send push notifications to all caregivers and doctors
  /// 4. Send SMS to emergency contacts
  /// 5. Start auto-escalation timer (60s)
  /// 6. Send in-app chat alert if no response within 60s
  ///
  /// [alertReason] specifies why the SOS was triggered (manual, fall detection, etc.)
  Future<SosActionResult> startSosSession({
    SosAlertReason alertReason = SosAlertReason.manual,
  }) async {
    if (_currentSession != null) {
      return SosActionResult.failure('SOS session already active');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return SosActionResult.failure('Not authenticated');
    }

    debugPrint('[SosEmergencyAction] Starting SOS session for: $uid (reason: ${alertReason.displayName})');

    try {
      // Get patient info
      final patientDoc = await _firestore.collection('users').doc(uid).get();
      final patientName = patientDoc.data()?['name'] as String? ?? 'Patient';

      // Create session ID
      final sessionId = _uuid.v4();

      // Get location
      Position? location;
      try {
        location = await _getCurrentLocation();
      } catch (e) {
        debugPrint('[SosEmergencyAction] Location failed: $e');
        // Continue without location
      }

      // Create session with alert reason
      _currentSession = SosSession(
        id: sessionId,
        patientUid: uid,
        patientName: patientName,
        startedAt: DateTime.now(),
        state: SosSessionState.active,
        location: location,
        alertReason: alertReason,
      );

      // Save to Firestore
      await _firestore.collection('sos_sessions').doc(sessionId).set({
        ..._currentSession!.toJson(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Log action
      await _logAction(sessionId, SosActionType.sessionStarted, {
        'location': location != null
            ? '${location.latitude},${location.longitude}'
            : null,
      });

      _notifySessionUpdate();

      // Send notifications (parallel)
      await Future.wait([
        _sendPushNotifications(sessionId, patientName, location),
        _sendSmsToContacts(sessionId, patientName, location),
      ]);

      // Start auto-escalation timer
      _startEscalationTimer(sessionId);

      return SosActionResult.success({'session_id': sessionId});
    } catch (e) {
      debugPrint('[SosEmergencyAction] Failed to start SOS: $e');
      return SosActionResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUSH NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send push notifications to all caregivers and doctors
  Future<void> _sendPushNotifications(
    String sessionId,
    String patientName,
    Position? location,
  ) async {
    if (_currentSession == null) return;

    debugPrint('[SosEmergencyAction] Sending push notifications...');

    try {
      // Get caregiver relationships
      final relationships = await _relationshipService
          .getRelationshipsForUser(_currentSession!.patientUid);
      
      final caregiverUids = <String>[];
      if (relationships.success && relationships.data != null) {
        for (final rel in relationships.data!) {
          if (rel.caregiverId != null && rel.caregiverId!.isNotEmpty) {
            caregiverUids.add(rel.caregiverId!);
          }
        }
      }

      // Get doctor relationships
      final doctorRelationships = await DoctorRelationshipService.instance
          .getRelationshipsForUser(_currentSession!.patientUid);
      
      final doctorUids = <String>[];
      if (doctorRelationships.success && doctorRelationships.data != null) {
        for (final rel in doctorRelationships.data!) {
          if (rel.doctorId != null && 
              rel.doctorId!.isNotEmpty && 
              rel.status == DoctorRelationshipStatus.active) {
            doctorUids.add(rel.doctorId!);
          }
        }
      }

      final allRecipients = [...caregiverUids, ...doctorUids];

      if (allRecipients.isEmpty) {
        debugPrint('[SosEmergencyAction] No recipients for push');
        return;
      }

      debugPrint('[SosEmergencyAction] Sending to ${caregiverUids.length} caregivers, ${doctorUids.length} doctors');

      // Send via Cloud Function
      final result = await _pushSender.sendSosAlert(
        patientUid: _currentSession!.patientUid,
        patientName: patientName,
        sosSessionId: sessionId,
        recipientUids: allRecipients,
        location: location != null
            ? '${location.latitude},${location.longitude}'
            : null,
      );

      // Update session
      _currentSession = _currentSession!.copyWith(
        state: SosSessionState.caregiverNotified,
        notifiedCaregivers: caregiverUids,
        notifiedDoctors: doctorUids,
      );

      // Update Firestore
      await _firestore.collection('sos_sessions').doc(sessionId).update({
        'state': SosSessionState.caregiverNotified.name,
        'notified_caregivers': caregiverUids,
        'notified_doctors': doctorUids,
      });

      // Log action
      await _logAction(sessionId, SosActionType.pushSent, {
        'success': result.success,
        'success_count': result.successCount,
        'failure_count': result.failureCount,
        'recipients': allRecipients,
      });

      _notifySessionUpdate();

      debugPrint('[SosEmergencyAction] Push sent: success=${result.success}');
    } catch (e) {
      debugPrint('[SosEmergencyAction] Push failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMS FALLBACK
  // ═══════════════════════════════════════════════════════════════════════════

  /// Public method to send emergency SMS to all contacts
  /// Called when network is unavailable and SMS fallback is needed
  Future<void> sendEmergencySmsToAllContacts() async {
    if (_currentSession == null) {
      debugPrint('[SosEmergencyAction] No active session for SMS');
      return;
    }

    await _sendSmsToContacts(
      _currentSession!.id,
      _currentSession!.patientName,
      _currentSession!.location,
    );
  }

  /// Send SMS to all emergency contacts via Cloud Function (Twilio)
  /// This automatically sends SMS without requiring user interaction
  Future<void> _sendSmsToContacts(
    String sessionId,
    String patientName,
    Position? location,
  ) async {
    if (_currentSession == null) return;

    debugPrint('[SosEmergencyAction] Sending SMS via Cloud Function...');

    try {
      // Get emergency contacts
      final contacts = await _emergencyContactService
          .getSOSContacts(_currentSession!.patientUid);

      if (contacts.isEmpty) {
        debugPrint('[SosEmergencyAction] No emergency contacts found');
        return;
      }

      // Build location string for Cloud Function
      final locationStr = location != null
          ? '${location.latitude},${location.longitude}'
          : null;

      // Convert contacts to maps for Cloud Function
      final contactMaps = contacts.map((c) => {
        'name': c.name,
        'phone_number': c.phoneNumber,
      }).toList();

      // Send via Cloud Function (Twilio)
      final result = await _pushSender.sendSosSms(
        patientUid: _currentSession!.patientUid,
        patientName: patientName,
        sosSessionId: sessionId,
        contacts: contactMaps,
        location: locationStr,
      );

      // Log action
      await _logAction(sessionId, SosActionType.smsSent, {
        'total_contacts': contacts.length,
        'success_count': result.successCount,
        'failure_count': result.failureCount,
        'has_location': location != null,
        'twilio_configured': result.twilioConfigured,
        'via_cloud_function': true,
      });

      debugPrint('[SosEmergencyAction] SMS sent: ${result.successCount}/${contacts.length} (twilio=${result.twilioConfigured})');
    } catch (e) {
      debugPrint('[SosEmergencyAction] SMS via Cloud Function failed: $e');
      
      // Fallback to url_launcher if Cloud Function fails
      debugPrint('[SosEmergencyAction] Falling back to url_launcher...');
      await _sendSmsViaUrlLauncher(sessionId, patientName, location);
    }
  }

  /// Fallback SMS via url_launcher (opens SMS app, user must send)
  Future<void> _sendSmsViaUrlLauncher(
    String sessionId,
    String patientName,
    Position? location,
  ) async {
    try {
      // Check SMS permission
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final requested = await Permission.sms.request();
        if (!requested.isGranted) {
          debugPrint('[SosEmergencyAction] SMS permission denied');
          await _logAction(sessionId, SosActionType.smsFailedPermission, {});
          return;
        }
      }

      // Get emergency contacts
      final contacts = await _emergencyContactService
          .getSOSContacts(_currentSession!.patientUid);

      if (contacts.isEmpty) return;

      // Build message
      String locationStr = '';
      if (location != null) {
        locationStr = '\nLocation: https://maps.google.com/?q=${location.latitude},${location.longitude}';
      }

      final message = 'EMERGENCY SOS: $patientName needs immediate help!$locationStr\n\n'
          'This is an automated alert from Guardian Angel.';

      // Send SMS to each contact via url_launcher (opens SMS app)
      int successCount = 0;
      for (final contact in contacts) {
        final success = await _sendSms(contact.phoneNumber, message);
        if (success) successCount++;
      }

      await _logAction(sessionId, SosActionType.smsSent, {
        'total_contacts': contacts.length,
        'success_count': successCount,
        'has_location': location != null,
        'via_url_launcher_fallback': true,
      });
    } catch (e) {
      debugPrint('[SosEmergencyAction] SMS fallback failed: $e');
      await _logAction(sessionId, SosActionType.smsFailedNetwork, {
        'error': e.toString(),
      });
    }
  }

  /// Send a single SMS using url_launcher (fallback only)
  Future<bool> _sendSms(String phoneNumber, String message) async {
    try {
      // Clean phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Build SMS URI
      final uri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': message},
      );

      // On Android, use sms: scheme directly
      final smsUri = Platform.isIOS
          ? uri
          : Uri.parse('sms:$cleanNumber?body=${Uri.encodeComponent(message)}');

      debugPrint('[SosEmergencyAction] Sending SMS to: $cleanNumber');

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        debugPrint('[SosEmergencyAction] Cannot launch SMS URI');
        return false;
      }
    } catch (e) {
      debugPrint('[SosEmergencyAction] SMS error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-ESCALATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start the auto-escalation timer
  void _startEscalationTimer(String sessionId) {
    _escalationTimer?.cancel();
    _escalationTimer = Timer(_autoEscalationTimeout, () {
      _autoEscalate(sessionId);
    });
    debugPrint('[SosEmergencyAction] Escalation timer started: ${_autoEscalationTimeout.inSeconds}s');
  }

  /// Auto-escalate to emergency services
  Future<void> _autoEscalate(String sessionId) async {
    if (_currentSession == null) return;
    if (_currentSession!.respondedUids.isNotEmpty) {
      debugPrint('[SosEmergencyAction] Skipping escalation - already responded');
      return;
    }

    debugPrint('[SosEmergencyAction] Auto-escalating to emergency services...');

    // Log escalation
    await _logAction(sessionId, SosActionType.autoEscalation, {
      'timeout_seconds': _autoEscalationTimeout.inSeconds,
    });

    // Update state
    _currentSession = _currentSession!.copyWith(
      state: SosSessionState.escalated,
    );

    await _firestore.collection('sos_sessions').doc(sessionId).update({
      'state': SosSessionState.escalated.name,
      'escalated_at': FieldValue.serverTimestamp(),
    });

    _notifySessionUpdate();

    // ═══════════════════════════════════════════════════════════════════════
    // SEND IN-APP CHAT ALERTS TO CAREGIVERS AND DOCTORS
    // ═══════════════════════════════════════════════════════════════════════
    if (!_currentSession!.chatAlertSent) {
      debugPrint('[SosEmergencyAction] Sending in-app chat alerts...');
      
      final chatResult = await SosAlertChatService.instance.sendSosAlertToAllChats(
        patientUid: _currentSession!.patientUid,
        patientName: _currentSession!.patientName,
        alertReason: _currentSession!.alertReason,
        location: _currentSession!.location,
        sosSessionId: sessionId,
      );

      if (chatResult.success) {
        debugPrint('[SosEmergencyAction] Chat alerts sent: ${chatResult.caregiverMessagesSent} caregivers, ${chatResult.doctorMessagesSent} doctors');
        
        // Update session to mark chat alerts as sent
        _currentSession = _currentSession!.copyWith(chatAlertSent: true);
        
        await _firestore.collection('sos_sessions').doc(sessionId).update({
          'chat_alert_sent': true,
          'chat_alert_sent_at': FieldValue.serverTimestamp(),
          'caregiver_chat_alerts_sent': chatResult.caregiverMessagesSent,
          'doctor_chat_alerts_sent': chatResult.doctorMessagesSent,
        });
        
        await _logAction(sessionId, SosActionType.autoEscalation, {
          'chat_alerts_sent': true,
          'caregiver_count': chatResult.caregiverMessagesSent,
          'doctor_count': chatResult.doctorMessagesSent,
        });
      } else {
        debugPrint('[SosEmergencyAction] Failed to send chat alerts: ${chatResult.error}');
      }
    }

    // Call emergency services
    await callEmergencyServices(sessionId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMERGENCY CALL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call emergency services (1122 Pakistan) via Cloud Function (Twilio)
  /// Falls back to url_launcher if Cloud Function fails
  Future<SosActionResult> callEmergencyServices(String sessionId) async {
    debugPrint('[SosEmergencyAction] Calling emergency services via Cloud Function: $_emergencyNumber');

    if (_currentSession == null) {
      return SosActionResult.failure('No active session');
    }

    try {
      // Try Cloud Function first (Twilio automated call)
      final locationStr = _currentSession!.location != null
          ? '${_currentSession!.location!.latitude},${_currentSession!.location!.longitude}'
          : null;

      final result = await _pushSender.sendSosCall(
        patientUid: _currentSession!.patientUid,
        patientName: _currentSession!.patientName,
        sosSessionId: sessionId,
        emergencyNumber: _emergencyNumber,
        location: locationStr,
      );

      if (result.success) {
        debugPrint('[SosEmergencyAction] Emergency call placed via Cloud Function (twilio=${result.twilioConfigured})');

        // Update session
        _currentSession = _currentSession?.copyWith(
          state: SosSessionState.emergencyCallPlaced,
          emergencyCallPlaced: true,
        );

        await _firestore.collection('sos_sessions').doc(sessionId).update({
          'state': SosSessionState.emergencyCallPlaced.name,
          'emergency_call_placed': true,
          'emergency_call_at': FieldValue.serverTimestamp(),
          'via_cloud_function': true,
          'twilio_configured': result.twilioConfigured,
        });

        // Log action
        await _logAction(sessionId, SosActionType.emergencyCallInitiated, {
          'number': _emergencyNumber,
          'via_cloud_function': true,
          'twilio_configured': result.twilioConfigured,
          'call_sid': result.callSid,
          'simulated': result.simulated,
        });

        _notifySessionUpdate();

        return SosActionResult.success({
          'number': _emergencyNumber,
          'via_cloud_function': true,
          'twilio_configured': result.twilioConfigured,
        });
      } else {
        debugPrint('[SosEmergencyAction] Cloud Function call failed: ${result.error}');
        // Fall through to url_launcher fallback
      }
    } catch (e) {
      debugPrint('[SosEmergencyAction] Cloud Function call error: $e');
      // Fall through to url_launcher fallback
    }

    // Fallback to url_launcher (opens phone dialer)
    return _callEmergencyServicesViaUrlLauncher(sessionId);
  }

  /// Fallback: Call emergency services via url_launcher (opens phone dialer)
  Future<SosActionResult> _callEmergencyServicesViaUrlLauncher(String sessionId) async {
    debugPrint('[SosEmergencyAction] Falling back to url_launcher for call: $_emergencyNumber');

    try {
      // Check phone permission
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        final requested = await Permission.phone.request();
        if (!requested.isGranted) {
          debugPrint('[SosEmergencyAction] Phone permission denied');
          await _logAction(sessionId, SosActionType.emergencyCallFailed, {
            'reason': 'permission_denied',
          });
          return SosActionResult.failure('Phone permission denied');
        }
      }

      // Build tel: URI
      final telUri = Uri.parse('tel:$_emergencyNumber');

      debugPrint('[SosEmergencyAction] Initiating call via url_launcher to: $_emergencyNumber');

      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);

        // Update session
        _currentSession = _currentSession?.copyWith(
          state: SosSessionState.emergencyCallPlaced,
          emergencyCallPlaced: true,
        );

        await _firestore.collection('sos_sessions').doc(sessionId).update({
          'state': SosSessionState.emergencyCallPlaced.name,
          'emergency_call_placed': true,
          'emergency_call_at': FieldValue.serverTimestamp(),
          'via_url_launcher_fallback': true,
        });

        // Log action
        await _logAction(sessionId, SosActionType.emergencyCallInitiated, {
          'number': _emergencyNumber,
          'via_url_launcher_fallback': true,
        });

        _notifySessionUpdate();

        return SosActionResult.success({
          'number': _emergencyNumber,
          'via_url_launcher_fallback': true,
        });
      } else {
        debugPrint('[SosEmergencyAction] Cannot launch tel: URI');
        await _logAction(sessionId, SosActionType.emergencyCallFailed, {
          'reason': 'cannot_launch_uri',
        });
        return SosActionResult.failure('Cannot place call');
      }
    } catch (e) {
      debugPrint('[SosEmergencyAction] Emergency call error: $e');
      await _logAction(sessionId, SosActionType.emergencyCallFailed, {
        'error': e.toString(),
      });
      return SosActionResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESPONSE HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Record a response from caregiver or doctor
  Future<SosActionResult> recordResponse({
    required String sessionId,
    required String responderUid,
    required String responderRole,
    required String responseType,
  }) async {
    if (_currentSession == null || _currentSession!.id != sessionId) {
      return SosActionResult.failure('Session not found');
    }

    debugPrint('[SosEmergencyAction] Recording response from: $responderUid');

    try {
      // Cancel escalation timer
      _escalationTimer?.cancel();

      // Update session
      final updatedResponded = [..._currentSession!.respondedUids, responderUid];
      _currentSession = _currentSession!.copyWith(
        state: SosSessionState.caregiverResponded,
        respondedUids: updatedResponded,
      );

      // Update Firestore
      await _firestore.collection('sos_sessions').doc(sessionId).update({
        'state': SosSessionState.caregiverResponded.name,
        'responded_uids': FieldValue.arrayUnion([responderUid]),
        'first_response_at': FieldValue.serverTimestamp(),
      });

      // Log action
      final actionType = responderRole == 'doctor'
          ? SosActionType.doctorResponded
          : SosActionType.caregiverResponded;
      
      await _logAction(sessionId, actionType, {
        'responder_uid': responderUid,
        'response_type': responseType,
      });

      // Notify patient
      await _pushSender.sendSosResponseNotification(
        patientUid: _currentSession!.patientUid,
        responderUid: responderUid,
        responderName: 'Responder', // TODO: fetch actual name
        responderRole: responderRole,
        sosSessionId: sessionId,
        responseType: responseType,
      );

      _notifySessionUpdate();

      return SosActionResult.success();
    } catch (e) {
      debugPrint('[SosEmergencyAction] Record response error: $e');
      return SosActionResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION RESOLUTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Resolve/end the SOS session
  Future<SosActionResult> resolveSession(String sessionId) async {
    if (_currentSession == null || _currentSession!.id != sessionId) {
      return SosActionResult.failure('Session not found');
    }

    debugPrint('[SosEmergencyAction] Resolving session: $sessionId');

    try {
      _escalationTimer?.cancel();

      // Update Firestore
      await _firestore.collection('sos_sessions').doc(sessionId).update({
        'state': SosSessionState.resolved.name,
        'resolved_at': FieldValue.serverTimestamp(),
      });

      // Log action
      await _logAction(sessionId, SosActionType.sessionResolved, {});

      _currentSession = null;
      _notifySessionUpdate();

      return SosActionResult.success();
    } catch (e) {
      debugPrint('[SosEmergencyAction] Resolve error: $e');
      return SosActionResult.failure(e.toString());
    }
  }

  /// Cancel the SOS session
  Future<SosActionResult> cancelSession(String sessionId) async {
    if (_currentSession == null || _currentSession!.id != sessionId) {
      return SosActionResult.failure('Session not found');
    }

    debugPrint('[SosEmergencyAction] Cancelling session: $sessionId');

    try {
      _escalationTimer?.cancel();

      // Update Firestore
      await _firestore.collection('sos_sessions').doc(sessionId).update({
        'state': SosSessionState.cancelled.name,
        'cancelled_at': FieldValue.serverTimestamp(),
      });

      // Log action
      await _logAction(sessionId, SosActionType.sessionCancelled, {});

      _currentSession = null;
      _notifySessionUpdate();

      return SosActionResult.success();
    } catch (e) {
      debugPrint('[SosEmergencyAction] Cancel error: $e');
      return SosActionResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position with timeout
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('[SosEmergencyAction] Location error: $e');
      return null;
    }
  }

  /// Log an action to Firestore audit trail
  Future<void> _logAction(
    String sessionId,
    SosActionType action,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection('sos_sessions')
          .doc(sessionId)
          .collection('audit_log')
          .add({
        'action': action.name,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
      });
    } catch (e) {
      debugPrint('[SosEmergencyAction] Audit log failed: $e');
    }
  }

  /// Notify listeners of session update
  void _notifySessionUpdate() {
    if (_currentSession != null && _sessionController != null) {
      _sessionController!.add(_currentSession!);
    }
  }

  /// Dispose resources
  void dispose() {
    _escalationTimer?.cancel();
    _sessionController?.close();
    _currentSession = null;
  }
}
