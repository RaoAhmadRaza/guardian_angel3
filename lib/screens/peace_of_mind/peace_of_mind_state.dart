/// Peace of Mind Screen State Model
/// 
/// Production-ready state for the wellness/reflection feature.
/// All fields are nullable to support first-time users with no data.
library;

/// Status of speech recognition and AI processing
enum SpeechStatus {
  /// Idle - ready for input
  idle,
  
  /// Actively listening to speech
  listening,
  
  /// Processing speech (transcribing or generating AI response)
  processing,
  
  /// Error occurred during speech or AI
  error,
}

/// Mood level enum for the mood slider
enum MoodLevel {
  cloudy,
  neutral,
  sunny;

  /// Convert mood level to slider value (0-100)
  double toSliderValue() {
    switch (this) {
      case MoodLevel.cloudy:
        return 0.0;
      case MoodLevel.neutral:
        return 50.0;
      case MoodLevel.sunny:
        return 100.0;
    }
  }

  /// Create mood level from slider value
  static MoodLevel fromSliderValue(double value) {
    if (value < 33.3) {
      return MoodLevel.cloudy;
    } else if (value < 66.6) {
      return MoodLevel.neutral;
    } else {
      return MoodLevel.sunny;
    }
  }
}

/// Data class for a soundscape audio option
class SoundscapeData {
  final String id;
  final String name;

  const SoundscapeData({
    required this.id,
    required this.name,
  });

  /// Create from local storage map
  factory SoundscapeData.fromMap(Map<String, dynamic> map) {
    return SoundscapeData(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Data class for a daily reflection prompt
class ReflectionPrompt {
  final String id;
  final String question;

  const ReflectionPrompt({
    required this.id,
    required this.question,
  });

  /// Create from local storage map
  factory ReflectionPrompt.fromMap(Map<String, dynamic> map) {
    return ReflectionPrompt(
      id: map['id'] as String? ?? '',
      question: map['question'] as String? ?? '',
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
    };
  }
}

/// Main state class for Peace of Mind screen
class PeaceOfMindState {
  /// Current mood level from slider
  final MoodLevel mood;
  
  /// Currently selected soundscape (null if none selected)
  final SoundscapeData? activeSoundscape;
  
  /// Today's reflection prompt (null if none available)
  final ReflectionPrompt? todayPrompt;
  
  /// Whether audio is currently playing
  final bool isPlayingSound;
  
  /// Whether user is recording a reflection
  final bool isRecordingReflection;
  
  // === Voice Reflection Fields ===
  
  /// Current status of speech recognition/AI processing
  final SpeechStatus speechStatus;
  
  /// Transcribed text from user's voice (if any)
  final String? transcribedText;
  
  /// AI-generated poetic reflection (if any)
  final String? aiGeneratedReflection;
  
  /// Error message if speech/AI failed
  final String? errorMessage;
  
  /// Whether AI response was a fallback (offline/error)
  final bool isAiFallback;
  
  /// Fallback reason message (if applicable)
  final String? fallbackReason;

  const PeaceOfMindState({
    required this.mood,
    this.activeSoundscape,
    this.todayPrompt,
    this.isPlayingSound = false,
    this.isRecordingReflection = false,
    this.speechStatus = SpeechStatus.idle,
    this.transcribedText,
    this.aiGeneratedReflection,
    this.errorMessage,
    this.isAiFallback = false,
    this.fallbackReason,
  });

  /// Initial state for first-time users
  /// Returns neutral mood with no soundscape or prompt
  factory PeaceOfMindState.initial() {
    return const PeaceOfMindState(
      mood: MoodLevel.neutral,
      activeSoundscape: null,
      todayPrompt: null,
      isPlayingSound: false,
      isRecordingReflection: false,
    );
  }

  /// Create a copy with updated fields
  PeaceOfMindState copyWith({
    MoodLevel? mood,
    SoundscapeData? activeSoundscape,
    bool clearSoundscape = false,
    ReflectionPrompt? todayPrompt,
    bool clearPrompt = false,
    bool? isPlayingSound,
    bool? isRecordingReflection,
    SpeechStatus? speechStatus,
    String? transcribedText,
    bool clearTranscribedText = false,
    String? aiGeneratedReflection,
    bool clearAiGeneratedReflection = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isAiFallback,
    String? fallbackReason,
    bool clearFallbackReason = false,
  }) {
    return PeaceOfMindState(
      mood: mood ?? this.mood,
      activeSoundscape: clearSoundscape ? null : (activeSoundscape ?? this.activeSoundscape),
      todayPrompt: clearPrompt ? null : (todayPrompt ?? this.todayPrompt),
      isPlayingSound: isPlayingSound ?? this.isPlayingSound,
      isRecordingReflection: isRecordingReflection ?? this.isRecordingReflection,
      speechStatus: speechStatus ?? this.speechStatus,
      transcribedText: clearTranscribedText ? null : (transcribedText ?? this.transcribedText),
      aiGeneratedReflection: clearAiGeneratedReflection ? null : (aiGeneratedReflection ?? this.aiGeneratedReflection),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isAiFallback: isAiFallback ?? this.isAiFallback,
      fallbackReason: clearFallbackReason ? null : (fallbackReason ?? this.fallbackReason),
    );
  }

  // === Computed Display Properties ===

  /// Whether a soundscape is selected
  bool get hasSoundscape => activeSoundscape != null;

  /// Display name for soundscape pill
  /// Returns "None" if no soundscape selected
  String get soundscapeDisplayName => activeSoundscape?.name ?? 'None';

  /// Whether a reflection prompt is available
  bool get hasPrompt => todayPrompt != null;
  
  /// Whether an AI-generated reflection is available
  bool get hasAiReflection => aiGeneratedReflection != null && aiGeneratedReflection!.isNotEmpty;
  
  /// Whether any reflection content is available (AI or prompt)
  bool get hasAnyReflection => hasAiReflection || hasPrompt;
  
  /// Whether the system is currently processing (listening or AI call)
  bool get isProcessing => speechStatus == SpeechStatus.listening || speechStatus == SpeechStatus.processing;
  
  /// Whether there's an error to display
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// Display text for reflection card
  /// Prioritizes AI-generated reflection over static prompts
  /// Shows status messages during processing
  String get reflectionDisplayText {
    switch (speechStatus) {
      case SpeechStatus.listening:
        return transcribedText?.isNotEmpty == true 
            ? transcribedText! 
            : 'Listening...';
      case SpeechStatus.processing:
        return 'Finding words of wisdom...';
      case SpeechStatus.error:
        return errorMessage ?? 'Something went wrong. Try again.';
      case SpeechStatus.idle:
        // Prioritize AI reflection, then prompt, then empty state
        if (hasAiReflection) {
          return aiGeneratedReflection!;
        }
        return todayPrompt?.question ?? 'Hold the mic to share your thoughts';
    }
  }
  
  /// Label for the reflection card header
  /// Changes based on content type
  String get reflectionCardLabel {
    if (speechStatus == SpeechStatus.listening) {
      return 'YOUR WORDS';
    }
    if (speechStatus == SpeechStatus.processing) {
      return 'REFLECTING...';
    }
    if (hasAiReflection) {
      return 'YOUR REFLECTION';
    }
    return 'DAILY REFLECTION';
  }

  /// Slider value for mood (0-100)
  double get moodSliderValue => mood.toSliderValue();
}
