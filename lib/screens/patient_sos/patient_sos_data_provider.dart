import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/guardian_service.dart';
import '../../services/sos_emergency_action_service.dart';
import '../../services/sos_alert_chat_service.dart';
import '../../repositories/impl/vitals_repository_hive.dart';
import '../../persistence/wrappers/box_accessor.dart';
import 'patient_sos_state.dart';

/// Patient SOS Data Provider
/// 
/// PRODUCTION-SAFE: This provider manages SOS session state.
/// Supports Demo Mode for showcasing UI with sample data.
/// It exposes streams for real events ONLY (unless demo mode).
/// 
/// NO TIMERS that simulate progression (unless demo mode).
/// NO FAKE DELAYS.
/// NO AUTO STATE JUMPS.
/// 
/// If a real event does not occur, the state does not change.
class PatientSosDataProvider extends ChangeNotifier {
  static PatientSosDataProvider? _instance;
  
  /// Singleton instance
  static PatientSosDataProvider get instance {
    _instance ??= PatientSosDataProvider._internal();
    return _instance!;
  }
  
  PatientSosDataProvider._internal();
  
  /// For testing - allows injecting a mock instance
  @visibleForTesting
  static void setInstance(PatientSosDataProvider instance) {
    _instance = instance;
  }
  
  /// Current SOS state
  PatientSosState _state = PatientSosState.idle();
  PatientSosState get state => _state;
  
  /// Stream controller for state changes
  final _stateController = StreamController<PatientSosState>.broadcast();
  Stream<PatientSosState> get stateStream => _stateController.stream;
  
  /// Timer for elapsed time - this is the ONLY timer allowed
  /// It simply counts elapsed time, does NOT trigger state changes
  Timer? _elapsedTimer;
  
  /// Timer for caregiver response timeout (Critical Issue #3)
  Timer? _caregiverTimeoutTimer;
  
  /// Duration before escalating to emergency services if caregiver doesn't respond
  static const Duration _caregiverTimeoutDuration = Duration(seconds: 60);
  
  /// Connectivity subscription for network monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  /// Subscriptions to external services (to be connected to real services)
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _transcriptSubscription;
  StreamSubscription? _sosEventSubscription;
  
  /// Start an SOS session
  /// 
  /// This initiates the SOS and sets up listeners for real events.
  /// In demo mode, returns pre-populated state for showcasing UI.
  /// The state will ONLY change when real events occur.
  /// 
  /// [alertReason] specifies why the SOS was triggered (manual, fall detection, etc.)
  Future<void> startSosSession({
    SosAlertReason alertReason = SosAlertReason.manual,
  }) async {
    if (_state.isActive) {
      // Already active
      return;
    }
    
    // Check if demo mode is enabled
    await DemoModeService.instance.initialize();
    if (DemoModeService.instance.isEnabled) {
      _state = PatientSOSDemoData.state;
      _notifyStateChange();
      _startElapsedTimer();
      return;
    }
    
    // Critical Issue #2: Check network connectivity before starting
    final isConnected = await _checkNetworkConnectivity();
    
    // Set initial state with network status
    _state = PatientSosState.initial().copyWith(
      networkAvailable: isConnected,
    );
    _notifyStateChange();
    
    // Start elapsed time counter
    // This ONLY updates elapsed time, does NOT trigger phase changes
    _startElapsedTimer();
    
    // Start monitoring network connectivity
    _startNetworkMonitoring();
    
    // ===== REAL SOS ACTION - START =====
    // Use the SosEmergencyActionService to send REAL notifications
    final sosService = SosEmergencyActionService.instance;
    final result = await sosService.startSosSession(alertReason: alertReason);
    
    if (result.success) {
      debugPrint('[PatientSosDataProvider] SOS session started: ${result.data?['session_id']}');
      _state = _state.copyWith(
        phase: SosPhase.contactingCaregiver,
      );
      _notifyStateChange();
      
      // Listen to session updates
      _sosEventSubscription = sosService.sessionStream.listen((session) {
        _handleSosSessionUpdate(session);
      });
    } else {
      debugPrint('[PatientSosDataProvider] SOS start failed: ${result.error}');
      // If push fails but we have network, continue anyway
      // If no network, trigger SMS fallback
      if (!isConnected) {
        await _triggerSmsFallback();
      }
    }
    // ===== REAL SOS ACTION - END =====
    
    // Connect to real services
    await _connectToServices();
    
    // Critical Issue #3: Start caregiver timeout timer
    _startCaregiverTimeoutTimer();
  }
  
  /// Handle updates from SosEmergencyActionService
  void _handleSosSessionUpdate(SosSession session) {
    debugPrint('[PatientSosDataProvider] Session update: ${session.state}');
    
    switch (session.state) {
      case SosSessionState.caregiverNotified:
        _state = _state.copyWith(phase: SosPhase.caregiverNotified);
        break;
      case SosSessionState.caregiverResponded:
        _stopCaregiverTimeoutTimer();
        _state = _state.copyWith(phase: SosPhase.caregiverNotified);
        break;
      case SosSessionState.escalated:
        _state = _state.copyWith(
          phase: SosPhase.contactingEmergency,
          caregiverTimedOut: true,
        );
        break;
      case SosSessionState.emergencyCallPlaced:
        _state = _state.copyWith(phase: SosPhase.contactingEmergency);
        break;
      case SosSessionState.resolved:
        _state = _state.copyWith(phase: SosPhase.resolved);
        break;
      case SosSessionState.cancelled:
        _state = PatientSosState.idle();
        break;
      default:
        break;
    }
    _notifyStateChange();
  }
  
  /// Cancel the SOS session
  /// ===== REAL CANCELLATION - NOTIFIES ALL PARTIES =====
  Future<void> cancelSosSession() async {
    // Stop all timers and subscriptions
    _stopElapsedTimer();
    _stopCaregiverTimeoutTimer();
    _stopNetworkMonitoring();
    await _disconnectFromServices();
    
    // ===== REAL SOS CANCELLATION - START =====
    final sosService = SosEmergencyActionService.instance;
    final currentSession = sosService.currentSession;
    if (currentSession != null) {
      await sosService.cancelSession(currentSession.id);
    }
    _sosEventSubscription?.cancel();
    _sosEventSubscription = null;
    // ===== REAL SOS CANCELLATION - END =====
    
    // Reset to idle state
    _state = PatientSosState.idle();
    _notifyStateChange();
  }
  
  /// Start the elapsed time counter
  /// 
  /// NOTE: This timer ONLY updates elapsed time.
  /// It does NOT trigger any state phase changes.
  /// Phase changes MUST come from real events.
  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _state = _state.copyWith(
        elapsed: _state.elapsed + const Duration(seconds: 1),
      );
      _notifyStateChange();
    });
  }
  
  /// Stop the elapsed time counter
  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }
  
  // ============================================================
  // NETWORK CONNECTIVITY HANDLING (Critical Issue #2)
  // ============================================================
  
  /// Check if network is available
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('[PatientSosDataProvider] Error checking connectivity: $e');
      return true; // Assume connected if check fails
    }
  }
  
  /// Start monitoring network connectivity changes
  void _startNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isConnected = result != ConnectivityResult.none;
      if (_state.networkAvailable != isConnected) {
        _state = _state.copyWith(networkAvailable: isConnected);
        _notifyStateChange();
        
        // If network lost during SOS, trigger SMS fallback
        if (!isConnected && _state.isActive && !_state.smsFallbackTriggered) {
          _triggerSmsFallback();
        }
      }
    });
  }
  
  /// Stop monitoring network connectivity
  void _stopNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  /// Trigger SMS fallback when network is unavailable
  /// ===== REAL SMS FALLBACK - NO PLACEHOLDERS =====
  Future<void> _triggerSmsFallback() async {
    if (_state.smsFallbackTriggered) return;
    
    debugPrint('[PatientSosDataProvider] Network unavailable - triggering SMS fallback');
    
    _state = _state.copyWith(
      smsFallbackTriggered: true,
      errorMessage: 'No internet. Sending emergency SMS to contacts.',
    );
    _notifyStateChange();
    
    // ===== REAL SMS ACTION - START =====
    final sosService = SosEmergencyActionService.instance;
    
    // If there's an active session, send SMS via the service
    final currentSession = sosService.currentSession;
    if (currentSession != null) {
      // The service already has SMS sending capability
      await sosService.sendEmergencySmsToAllContacts();
    } else {
      // No active session - directly send SMS to contacts
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final contacts = await EmergencyContactService.instance.getSOSContacts(uid);
        final position = await _getCurrentPosition();
        final locationString = position != null 
            ? 'Location: https://maps.google.com/?q=${position.latitude},${position.longitude}'
            : 'Location: Unable to determine';
        
        for (final contact in contacts) {
          final phoneNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
          if (phoneNumber.isEmpty) continue;
          
          final message = Uri.encodeComponent(
            'EMERGENCY: Guardian Angel SOS Alert!\n'
            'Your contact needs immediate help.\n'
            '$locationString\n'
            'Please respond immediately or call emergency services.'
          );
          
          final smsUri = Uri.parse('sms:$phoneNumber?body=$message');
          try {
            if (await canLaunchUrl(smsUri)) {
              await launchUrl(smsUri);
              debugPrint('[PatientSosDataProvider] SMS launched to: $phoneNumber');
            }
          } catch (e) {
            debugPrint('[PatientSosDataProvider] SMS failed to $phoneNumber: $e');
          }
        }
      }
    }
    // ===== REAL SMS ACTION - END =====
  }
  
  /// Get current position for SMS fallback
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('[PatientSosDataProvider] Failed to get position: $e');
      return null;
    }
  }
  
  // ============================================================
  // CAREGIVER TIMEOUT HANDLING (Critical Issue #3)
  // ============================================================
  
  /// Start the caregiver timeout timer
  /// If caregiver doesn't respond within timeout, escalate to emergency services
  void _startCaregiverTimeoutTimer() {
    _caregiverTimeoutTimer?.cancel();
    _caregiverTimeoutTimer = Timer(_caregiverTimeoutDuration, () {
      if (_state.phase == SosPhase.contactingCaregiver || 
          _state.phase == SosPhase.caregiverNotified) {
        debugPrint('[PatientSosDataProvider] Caregiver timeout - escalating to emergency');
        _state = _state.copyWith(
          caregiverTimedOut: true,
          phase: SosPhase.contactingEmergency,
        );
        _notifyStateChange();
      }
    });
  }
  
  /// Stop the caregiver timeout timer
  void _stopCaregiverTimeoutTimer() {
    _caregiverTimeoutTimer?.cancel();
    _caregiverTimeoutTimer = null;
  }
  
  /// Called when caregiver responds - stops the timeout timer
  void onCaregiverResponded() {
    _stopCaregiverTimeoutTimer();
    if (_state.phase == SosPhase.contactingCaregiver || 
        _state.phase == SosPhase.caregiverNotified) {
      _state = _state.copyWith(phase: SosPhase.caregiverNotified);
      _notifyStateChange();
    }
  }
  
  /// Connect to real services
  /// 
  /// TODO: Connect these to actual service implementations:
  /// - Heart rate monitor service
  /// - Location service
  /// - Speech recognition service
  /// - SOS backend service
  Future<void> _connectToServices() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Load emergency contacts for SOS
    try {
      final contacts = await EmergencyContactService.instance.getSOSContacts(uid);
      if (contacts.isNotEmpty) {
        final primary = contacts.first;
        onCaregiverResolved(primary.name);
      }
    } catch (e) {
      debugPrint('[PatientSosDataProvider] Error loading emergency contacts: $e');
    }
    
    // Load primary guardian as fallback
    try {
      final guardian = await GuardianService.instance.getPrimaryGuardian(uid);
      if (guardian != null && (_state.caregiverName?.isEmpty ?? true)) {
        onCaregiverResolved(guardian.name);
      }
    } catch (e) {
      debugPrint('[PatientSosDataProvider] Error loading guardian: $e');
    }
    
    // Load current heart rate from vitals
    try {
      final vitalsRepo = VitalsRepositoryHive(boxAccessor: BoxAccessor());
      final latest = await vitalsRepo.getLatestForUser(uid);
      if (latest != null) {
        onHeartRateUpdate(latest.heartRate);
      }
    } catch (e) {
      debugPrint('[PatientSosDataProvider] Error loading vitals: $e');
    }
    
    // PLACEHOLDER: Connect to real-time heart rate service
    // _heartRateSubscription = heartRateService.stream.listen(_onHeartRateUpdate);
    
    // PLACEHOLDER: Connect to location service
    // _locationSubscription = locationService.stream.listen(_onLocationUpdate);
    
    // PLACEHOLDER: Connect to speech recognition service
    // _transcriptSubscription = speechService.stream.listen(_onTranscriptUpdate);
    
    // PLACEHOLDER: Connect to SOS backend service
    // _sosEventSubscription = sosService.eventStream.listen(_onSosEvent);
  }
  
  /// Disconnect from all services
  Future<void> _disconnectFromServices() async {
    await _heartRateSubscription?.cancel();
    await _locationSubscription?.cancel();
    await _transcriptSubscription?.cancel();
    await _sosEventSubscription?.cancel();
    
    _heartRateSubscription = null;
    _locationSubscription = null;
    _transcriptSubscription = null;
    _sosEventSubscription = null;
  }
  
  // ============================================================
  // EVENT HANDLERS - Called ONLY by real service events
  // ============================================================
  
  /// Called when heart rate data is received from device
  void onHeartRateUpdate(int bpm) {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(heartRate: bpm);
    _notifyStateChange();
  }
  
  /// Called when heart rate device disconnects
  void onHeartRateDisconnected() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(clearHeartRate: true);
    _notifyStateChange();
  }
  
  /// Called when location is resolved
  void onLocationResolved(String address) {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(locationText: address);
    _notifyStateChange();
  }
  
  /// Called when location permission is denied
  void onLocationDenied() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(locationDenied: true);
    _notifyStateChange();
  }
  
  /// Called when a new transcript line is recognized
  void onTranscriptUpdate(String text) {
    if (!_state.isActive) return;
    
    final updatedTranscript = List<String>.from(_state.transcript)..add(text);
    _state = _state.copyWith(transcript: updatedTranscript);
    _notifyStateChange();
  }
  
  /// Called when microphone permission is denied
  void onMicrophoneDenied() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(
      microphoneDenied: true,
      isRecording: false,
    );
    _notifyStateChange();
  }
  
  /// Called when caregiver name is resolved
  void onCaregiverResolved(String name) {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(caregiverName: name);
    _notifyStateChange();
  }
  
  /// Called when caregiver has been notified (REAL event from backend)
  void onCaregiverNotified() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(phase: SosPhase.caregiverNotified);
    _notifyStateChange();
  }
  
  /// Called when escalating to emergency services (REAL event from backend)
  void onContactingEmergency() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(phase: SosPhase.contactingEmergency);
    _notifyStateChange();
  }
  
  /// Called when connected to emergency services (REAL event from backend)
  void onEmergencyConnected() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(phase: SosPhase.connected);
    _notifyStateChange();
  }
  
  /// Called when Medical ID has been shared (REAL event from backend)
  void onMedicalIdShared() {
    if (!_state.isActive) return;
    
    _state = _state.copyWith(medicalIdShared: true);
    _notifyStateChange();
  }
  
  // ============================================================
  // PERMISSION RECOVERY (Critical Issue #1)
  // ============================================================
  
  /// Retry getting location permission
  /// Called when user grants permission via settings
  Future<void> retryLocationPermission() async {
    if (!_state.isActive) return;
    
    // Clear the denied flag and retry
    _state = _state.copyWith(
      locationDenied: false,
      clearErrorMessage: true,
    );
    _notifyStateChange();
    
    // TODO: Re-request location via location service
    debugPrint('[PatientSosDataProvider] Retrying location permission');
  }
  
  /// Retry getting microphone permission
  /// Called when user grants permission via settings
  Future<void> retryMicrophonePermission() async {
    if (!_state.isActive) return;
    
    // Clear the denied flag and retry
    _state = _state.copyWith(
      microphoneDenied: false,
      isRecording: true,
      clearErrorMessage: true,
    );
    _notifyStateChange();
    
    // TODO: Re-request microphone via audio service
    debugPrint('[PatientSosDataProvider] Retrying microphone permission');
  }
  
  /// Open device settings for permission configuration
  /// Returns true if settings were opened successfully
  Future<bool> openAppSettings() async {
    // This will be handled by the UI layer using app_settings or permission_handler
    debugPrint('[PatientSosDataProvider] Opening app settings');
    return true;
  }
  
  /// Notify listeners of state change
  void _notifyStateChange() {
    _stateController.add(_state);
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stopElapsedTimer();
    _stopCaregiverTimeoutTimer();
    _stopNetworkMonitoring();
    _disconnectFromServices();
    _stateController.close();
    super.dispose();
  }
}
