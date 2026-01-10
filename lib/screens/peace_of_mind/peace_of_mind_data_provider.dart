/// Peace of Mind Data Provider
/// 
/// Loads wellness data from local storage ONLY.
/// Supports Demo Mode for showcasing UI with sample data.
/// Returns null values for first-time users when demo mode is off.
library;

import 'package:hive_flutter/hive_flutter.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import 'peace_of_mind_state.dart';

/// Data provider for Peace of Mind screen
/// 
/// Responsibilities:
/// - Load saved mood from local storage
/// - Return demo data when Demo Mode is enabled
/// - Load today's reflection prompt if exists
/// - Load last selected soundscape if exists
/// - Persist mood changes locally
class PeaceOfMindDataProvider {
  static PeaceOfMindDataProvider? _instance;
  
  /// Singleton instance
  static PeaceOfMindDataProvider get instance {
    _instance ??= PeaceOfMindDataProvider._();
    return _instance!;
  }
  
  PeaceOfMindDataProvider._();

  /// Hive box name for peace of mind data
  static const String _boxName = 'peace_of_mind_data';
  
  /// Keys for stored values
  static const String _moodKey = 'saved_mood';
  static const String _soundscapeKey = 'active_soundscape';
  static const String _promptKey = 'today_prompt';
  static const String _aiReflectionKey = 'ai_reflection';
  static const String _aiReflectionTimestampKey = 'ai_reflection_timestamp';

  Box<dynamic>? _box;

  /// Initialize the data provider (open Hive box)
  Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  /// Load initial state from local storage
  /// Returns demo data if Demo Mode is enabled
  /// Returns initial state with null values for first-time users when demo mode is off
  Future<PeaceOfMindState> loadInitialState() async {
    await initialize();
    
    // Check if demo mode is enabled
    await DemoModeService.instance.initialize();
    if (DemoModeService.instance.isEnabled) {
      return PeaceOfMindDemoData.state;
    }
    
    // Load real data from Hive
    // Load saved mood level
    final savedMoodValue = _box?.get(_moodKey) as double?;
    final mood = savedMoodValue != null 
        ? MoodLevel.fromSliderValue(savedMoodValue)
        : MoodLevel.neutral;
    
    // Load active soundscape (null if none saved)
    final soundscapeMap = _box?.get(_soundscapeKey) as Map<dynamic, dynamic>?;
    final activeSoundscape = soundscapeMap != null
        ? SoundscapeData.fromMap(Map<String, dynamic>.from(soundscapeMap))
        : null;
    
    // Load today's reflection prompt (null if none exists)
    final promptMap = _box?.get(_promptKey) as Map<dynamic, dynamic>?;
    final todayPrompt = promptMap != null
        ? ReflectionPrompt.fromMap(Map<String, dynamic>.from(promptMap))
        : null;
    
    // Load last AI-generated reflection (if from today)
    final aiReflection = _getAiReflectionIfFromToday();

    return PeaceOfMindState(
      mood: mood,
      activeSoundscape: activeSoundscape,
      todayPrompt: todayPrompt,
      isPlayingSound: false, // Never auto-play
      isRecordingReflection: false,
      aiGeneratedReflection: aiReflection,
    );
  }
  
  /// Get AI reflection only if it was generated today
  /// Returns null if reflection is from a previous day
  String? _getAiReflectionIfFromToday() {
    final reflection = _box?.get(_aiReflectionKey) as String?;
    final timestampMillis = _box?.get(_aiReflectionTimestampKey) as int?;
    
    if (reflection == null || timestampMillis == null) {
      return null;
    }
    
    final savedDate = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
    final now = DateTime.now();
    
    // Check if same day
    if (savedDate.year == now.year && 
        savedDate.month == now.month && 
        savedDate.day == now.day) {
      return reflection;
    }
    
    // Reflection is from a previous day, don't show it
    return null;
  }

  /// Save mood value to local storage
  Future<void> saveMood(double sliderValue) async {
    await initialize();
    await _box?.put(_moodKey, sliderValue);
  }

  /// Save selected soundscape to local storage
  Future<void> saveSoundscape(SoundscapeData soundscape) async {
    await initialize();
    await _box?.put(_soundscapeKey, soundscape.toMap());
  }

  /// Clear saved soundscape
  Future<void> clearSoundscape() async {
    await initialize();
    await _box?.delete(_soundscapeKey);
  }

  /// Save reflection prompt (used by admin/backend)
  Future<void> savePrompt(ReflectionPrompt prompt) async {
    await initialize();
    await _box?.put(_promptKey, prompt.toMap());
  }

  /// Clear today's prompt
  Future<void> clearPrompt() async {
    await initialize();
    await _box?.delete(_promptKey);
  }
  
  /// Save AI-generated reflection with timestamp
  Future<void> saveAiReflection(String reflection) async {
    await initialize();
    await _box?.put(_aiReflectionKey, reflection);
    await _box?.put(_aiReflectionTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Clear saved AI reflection
  Future<void> clearAiReflection() async {
    await initialize();
    await _box?.delete(_aiReflectionKey);
    await _box?.delete(_aiReflectionTimestampKey);
  }

  /// Check if user has any saved wellness data
  Future<bool> hasAnyData() async {
    await initialize();
    return _box?.get(_moodKey) != null ||
           _box?.get(_soundscapeKey) != null ||
           _box?.get(_promptKey) != null ||
           _box?.get(_aiReflectionKey) != null;
  }
}
