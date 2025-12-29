/// Patient AI Chat Screen State Model
/// 
/// Production-safe state model for AI chat screen.
/// First-time users see minimal, honest empty states.
/// 
/// NO FAKE DATA - All fields are nullable or empty by default.

/// Input mode for the chat interface
enum InputMode { voice, keyboard }

/// A single chat message
class ChatMessage {
  final String id;
  final String text;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final String status; // 'sending', 'sent', 'delivered', 'read'

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.status = 'sent',
  });
  
  /// Check if this is a user message
  bool get isUser => sender == 'user';
  
  /// Check if this is an AI message
  bool get isAI => sender == 'ai';
}

/// Preview of caregiver for quick action widget
class CaregiverPreview {
  final String id;
  final String name;
  final String? relationship; // "Daughter", "Son", "Spouse", etc.
  final bool isOnline;
  final String? imageUrl;

  const CaregiverPreview({
    required this.id,
    required this.name,
    this.relationship,
    this.isOnline = false,
    this.imageUrl,
  });
  
  /// Get first letter for avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
  
  /// Get display subtitle
  String get subtitle {
    final parts = <String>[];
    if (relationship != null) parts.add(relationship!);
    parts.add(isOnline ? 'Online' : 'Offline');
    return parts.join(' • ');
  }
}

/// Main state model for Patient AI Chat Screen
class PatientAIChatState {
  /// Whether health monitoring is currently active
  final bool isMonitoringActive;
  
  /// Current heart rate - null if no device connected or no reading
  final int? heartRate;
  
  /// Chat message history
  final List<ChatMessage> messages;
  
  /// Primary caregiver for quick call - null if none added
  final CaregiverPreview? caregiver;
  
  /// Whether AI is currently generating a response
  final bool isAITyping;
  
  /// Current input mode (voice or keyboard)
  final InputMode inputMode;
  
  /// Whether voice is currently being recorded
  final bool isRecording;
  
  /// Monitoring status text to display
  final String monitoringStatusText;

  const PatientAIChatState({
    required this.isMonitoringActive,
    this.heartRate,
    required this.messages,
    this.caregiver,
    required this.isAITyping,
    required this.inputMode,
    required this.isRecording,
    required this.monitoringStatusText,
  });

  /// Create initial empty state for first-time users
  /// 
  /// Returns a state with:
  /// - No heart rate (no device connected)
  /// - Single welcome message
  /// - No caregiver
  /// - Not typing, not recording
  /// - Monitoring inactive
  factory PatientAIChatState.initial() {
    return PatientAIChatState(
      isMonitoringActive: false,
      heartRate: null,
      messages: [
        ChatMessage(
          id: 'welcome',
          text: "I'm here whenever you're ready.",
          sender: 'ai',
          timestamp: DateTime.now(),
          status: 'sent',
        ),
      ],
      caregiver: null,
      isAITyping: false,
      inputMode: InputMode.voice,
      isRecording: false,
      monitoringStatusText: 'Idle',
    );
  }
  
  /// Check if user has a connected health device
  bool get hasHealthDevice => heartRate != null;
  
  /// Check if user has a caregiver
  bool get hasCaregiver => caregiver != null;
  
  /// Check if there are any messages beyond the welcome
  bool get hasConversation => messages.length > 1;
  
  /// Get heart rate display string
  String get heartRateDisplay {
    if (heartRate == null) return '-- BPM';
    return '$heartRate BPM';
  }
  
  /// Create a copy with updated fields
  PatientAIChatState copyWith({
    bool? isMonitoringActive,
    int? heartRate,
    List<ChatMessage>? messages,
    CaregiverPreview? caregiver,
    bool? isAITyping,
    InputMode? inputMode,
    bool? isRecording,
    String? monitoringStatusText,
    bool clearHeartRate = false,
    bool clearCaregiver = false,
  }) {
    return PatientAIChatState(
      isMonitoringActive: isMonitoringActive ?? this.isMonitoringActive,
      heartRate: clearHeartRate ? null : (heartRate ?? this.heartRate),
      messages: messages ?? this.messages,
      caregiver: clearCaregiver ? null : (caregiver ?? this.caregiver),
      isAITyping: isAITyping ?? this.isAITyping,
      inputMode: inputMode ?? this.inputMode,
      isRecording: isRecording ?? this.isRecording,
      monitoringStatusText: monitoringStatusText ?? this.monitoringStatusText,
    );
  }
}

// Fix for const ChatMessage with null timestamp
extension ChatMessageExtension on ChatMessage {
  DateTime get displayTimestamp => timestamp;
}
