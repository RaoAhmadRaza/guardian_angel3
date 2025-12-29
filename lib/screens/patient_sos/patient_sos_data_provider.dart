import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
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
  Future<void> startSosSession() async {
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
    
    // Set initial state
    _state = PatientSosState.initial();
    _notifyStateChange();
    
    // Start elapsed time counter
    // This ONLY updates elapsed time, does NOT trigger phase changes
    _startElapsedTimer();
    
    // Connect to real services (stubs for now - will be connected to real services)
    await _connectToServices();
  }
  
  /// Cancel the SOS session
  Future<void> cancelSosSession() async {
    // Stop all timers and subscriptions
    _stopElapsedTimer();
    await _disconnectFromServices();
    
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
  
  /// Connect to real services
  /// 
  /// TODO: Connect these to actual service implementations:
  /// - Heart rate monitor service
  /// - Location service
  /// - Speech recognition service
  /// - SOS backend service
  Future<void> _connectToServices() async {
    // PLACEHOLDER: Connect to heart rate service
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
  
  /// Notify listeners of state change
  void _notifyStateChange() {
    _stateController.add(_state);
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stopElapsedTimer();
    _disconnectFromServices();
    _stateController.close();
    super.dispose();
  }
}
