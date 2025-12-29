/// Peace of Mind Screen State Model
/// 
/// Production-ready state for the wellness/reflection feature.
/// All fields are nullable to support first-time users with no data.
library;

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

  const PeaceOfMindState({
    required this.mood,
    this.activeSoundscape,
    this.todayPrompt,
    this.isPlayingSound = false,
    this.isRecordingReflection = false,
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
  }) {
    return PeaceOfMindState(
      mood: mood ?? this.mood,
      activeSoundscape: clearSoundscape ? null : (activeSoundscape ?? this.activeSoundscape),
      todayPrompt: clearPrompt ? null : (todayPrompt ?? this.todayPrompt),
      isPlayingSound: isPlayingSound ?? this.isPlayingSound,
      isRecordingReflection: isRecordingReflection ?? this.isRecordingReflection,
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

  /// Display text for reflection card
  /// Returns empty state message if no prompt
  String get reflectionDisplayText => 
      todayPrompt?.question ?? 'No reflection for today';

  /// Slider value for mood (0-100)
  double get moodSliderValue => mood.toSliderValue();
}
