/// Patient SOS State Model
/// 
/// PRODUCTION-SAFE: This model defines the state for the SOS emergency screen.
/// All fields are nullable or have safe defaults for first-time users.
/// NO fake data. NO simulated values.

/// SOS session phases - represents real progression only
enum SosPhase {
  /// Initial state - no SOS active
  idle,
  
  /// SOS initiated, attempting to contact caregiver
  contactingCaregiver,
  
  /// Caregiver has been successfully notified
  caregiverNotified,
  
  /// Escalating to emergency services
  contactingEmergency,
  
  /// Connected to emergency services
  connected,
  
  /// SOS session has been resolved (help arrived or situation handled)
  resolved,
}

/// Immutable state for Patient SOS Screen
/// 
/// All fields that depend on external data are nullable.
/// The UI must handle null gracefully with honest fallbacks.
class PatientSosState {
  /// Current phase of the SOS session
  final SosPhase phase;
  
  /// Elapsed time since SOS was initiated
  /// Updated ONLY by real timer events, not simulations
  final Duration elapsed;
  
  /// Current heart rate from connected device
  /// null = no device connected or data unavailable
  final int? heartRate;
  
  /// Name of the caregiver being contacted
  /// null = no caregiver assigned or name unavailable
  final String? caregiverName;
  
  /// Resolved location address
  /// null = location not yet resolved or unavailable
  final String? locationText;
  
  /// Voice transcript lines from microphone
  /// Empty list = no transcript yet (show "Listening...")
  final List<String> transcript;
  
  /// Whether Medical ID has been shared with responders
  /// Only true when backend confirms sharing
  final bool medicalIdShared;
  
  /// Whether microphone is actively recording
  final bool isRecording;
  
  /// Whether location permission was denied
  final bool locationDenied;
  
  /// Whether microphone permission was denied
  final bool microphoneDenied;
  
  /// Whether network is available (for SOS transmission)
  final bool networkAvailable;
  
  /// Whether caregiver response timed out
  final bool caregiverTimedOut;
  
  /// Error message for user display (null = no error)
  final String? errorMessage;
  
  /// Whether SMS fallback was triggered
  final bool smsFallbackTriggered;

  const PatientSosState({
    required this.phase,
    required this.elapsed,
    this.heartRate,
    this.caregiverName,
    this.locationText,
    this.transcript = const [],
    this.medicalIdShared = false,
    this.isRecording = false,
    this.locationDenied = false,
    this.microphoneDenied = false,
    this.networkAvailable = true,
    this.caregiverTimedOut = false,
    this.errorMessage,
    this.smsFallbackTriggered = false,
  });

  /// Initial state when SOS is first triggered
  /// 
  /// This represents the honest first-frame state:
  /// - Phase is contactingCaregiver (SOS has been initiated)
  /// - No elapsed time yet
  /// - No heart rate data yet
  /// - No caregiver name yet (will be resolved)
  /// - No location yet (will be resolved)
  /// - No transcript yet
  /// - Medical ID not yet shared
  /// - Recording starts immediately
  factory PatientSosState.initial() {
    return const PatientSosState(
      phase: SosPhase.contactingCaregiver,
      elapsed: Duration.zero,
      heartRate: null,
      caregiverName: null,
      locationText: null,
      transcript: [],
      medicalIdShared: false,
      isRecording: true,
      locationDenied: false,
      microphoneDenied: false,
      networkAvailable: true,
      caregiverTimedOut: false,
      errorMessage: null,
      smsFallbackTriggered: false,
    );
  }

  /// Idle state - no SOS active
  factory PatientSosState.idle() {
    return const PatientSosState(
      phase: SosPhase.idle,
      elapsed: Duration.zero,
      heartRate: null,
      caregiverName: null,
      locationText: null,
      transcript: [],
      medicalIdShared: false,
      isRecording: false,
      locationDenied: false,
      microphoneDenied: false,
      networkAvailable: true,
      caregiverTimedOut: false,
      errorMessage: null,
      smsFallbackTriggered: false,
    );
  }

  /// Create a copy with updated fields
  PatientSosState copyWith({
    SosPhase? phase,
    Duration? elapsed,
    int? heartRate,
    String? caregiverName,
    String? locationText,
    List<String>? transcript,
    bool? medicalIdShared,
    bool? isRecording,
    bool? locationDenied,
    bool? microphoneDenied,
    bool? networkAvailable,
    bool? caregiverTimedOut,
    String? errorMessage,
    bool? smsFallbackTriggered,
    bool clearHeartRate = false,
    bool clearCaregiverName = false,
    bool clearLocationText = false,
    bool clearErrorMessage = false,
  }) {
    return PatientSosState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      heartRate: clearHeartRate ? null : (heartRate ?? this.heartRate),
      caregiverName: clearCaregiverName ? null : (caregiverName ?? this.caregiverName),
      locationText: clearLocationText ? null : (locationText ?? this.locationText),
      transcript: transcript ?? this.transcript,
      medicalIdShared: medicalIdShared ?? this.medicalIdShared,
      isRecording: isRecording ?? this.isRecording,
      locationDenied: locationDenied ?? this.locationDenied,
      microphoneDenied: microphoneDenied ?? this.microphoneDenied,
      networkAvailable: networkAvailable ?? this.networkAvailable,
      caregiverTimedOut: caregiverTimedOut ?? this.caregiverTimedOut,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      smsFallbackTriggered: smsFallbackTriggered ?? this.smsFallbackTriggered,
    );
  }

  /// Get the main status text based on current phase
  String get mainStatusText {
    switch (phase) {
      case SosPhase.idle:
        return "SOS Ready";
      case SosPhase.contactingCaregiver:
        return "Contacting caregiver...";
      case SosPhase.caregiverNotified:
        // Use caregiver name if available, otherwise generic text
        return caregiverName != null 
            ? "$caregiverName notified" 
            : "Caregiver notified";
      case SosPhase.contactingEmergency:
        return "Emergency services";
      case SosPhase.connected:
        return "Connected";
      case SosPhase.resolved:
        return "Resolved";
    }
  }

  /// Get the sub-status text based on current phase
  String get subStatusText {
    switch (phase) {
      case SosPhase.idle:
        return "Press SOS to activate";
      case SosPhase.contactingCaregiver:
        return "Transmitting vitals...";
      case SosPhase.caregiverNotified:
        return "Awaiting response...";
      case SosPhase.contactingEmergency:
        return "Connecting line...";
      case SosPhase.connected:
        return "Help is on the way";
      case SosPhase.resolved:
        return "Emergency handled";
    }
  }

  /// Get the display text for heart rate
  String get heartRateDisplay {
    return heartRate?.toString() ?? "--";
  }

  /// Get the display text for location
  String get locationDisplay {
    if (locationDenied) {
      return "Location unavailable";
    }
    return locationText ?? "Locating...";
  }

  /// Get the display text for transcript
  String get transcriptDisplay {
    if (microphoneDenied) {
      return "Microphone unavailable";
    }
    if (transcript.isEmpty) {
      return "Listening...";
    }
    return '"${transcript.last}"';
  }

  /// Whether to show the heart rate waveform animation
  bool get showHeartWaveform => heartRate != null;

  /// Whether to show the microphone waveform animation
  bool get showMicWaveform => isRecording && !microphoneDenied;

  /// Format elapsed time as MM:SS
  String get elapsedDisplay {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  /// Whether the SOS session is active
  bool get isActive => phase != SosPhase.idle;

  /// Current step for the progress indicator (0, 1, or 2)
  int get progressStep {
    switch (phase) {
      case SosPhase.idle:
      case SosPhase.contactingCaregiver:
        return 0;
      case SosPhase.caregiverNotified:
        return 1;
      case SosPhase.contactingEmergency:
      case SosPhase.connected:
      case SosPhase.resolved:
        return 2;
    }
  }
  
  /// Whether there is a permission issue that needs user action
  bool get hasPermissionIssue => locationDenied || microphoneDenied;
  
  /// Whether there is a network connectivity issue
  bool get hasNetworkIssue => !networkAvailable;
  
  /// Whether the SOS is in an error state requiring attention
  bool get hasError => errorMessage != null || hasPermissionIssue || hasNetworkIssue;
  
  /// Get a user-friendly error description
  String get errorDescription {
    if (!networkAvailable) {
      return "No internet connection. Emergency SMS will be sent instead.";
    }
    if (locationDenied && microphoneDenied) {
      return "Location and microphone access denied. Tap to enable in Settings.";
    }
    if (locationDenied) {
      return "Location access denied. Tap to enable in Settings for accurate help.";
    }
    if (microphoneDenied) {
      return "Microphone access denied. Tap to enable in Settings for voice recording.";
    }
    if (caregiverTimedOut) {
      return "Caregiver not responding. Escalating to emergency services.";
    }
    return errorMessage ?? "";
  }
}
