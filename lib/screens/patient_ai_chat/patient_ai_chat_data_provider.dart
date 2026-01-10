/// Patient AI Chat Data Provider
/// 
/// Production-safe data loading service for AI chat screen.
/// Integrates with AIChatService, VitalsRepository, GuardianService.
/// 
/// NO FAKE DATA - Returns null/empty when data doesn't exist.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:guardian_angel_fyp/screens/patient_ai_chat/patient_ai_chat_state.dart';
import 'package:guardian_angel_fyp/services/guardian_ai_service.dart';
import 'package:guardian_angel_fyp/services/ai_chat_service.dart';
import 'package:guardian_angel_fyp/services/guardian_service.dart';
import 'package:guardian_angel_fyp/repositories/vitals_repository.dart';
import 'package:guardian_angel_fyp/repositories/impl/vitals_repository_hive.dart';
import 'package:guardian_angel_fyp/persistence/wrappers/box_accessor.dart';

/// Singleton data provider for patient AI chat screen
class PatientAIChatDataProvider {
  // Singleton instance
  static final PatientAIChatDataProvider _instance = PatientAIChatDataProvider._internal();
  factory PatientAIChatDataProvider() => _instance;
  PatientAIChatDataProvider._internal();

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  
  // Lazy-loaded VitalsRepository
  VitalsRepository? _vitalsRepository;
  VitalsRepository get _vitalsRepo {
    _vitalsRepository ??= VitalsRepositoryHive(boxAccessor: BoxAccessor());
    return _vitalsRepository!;
  }

  /// Load initial state for AI chat screen
  /// 
  /// For first-time users, returns welcome message only.
  Future<PatientAIChatState> loadInitialState() async {
    final uid = _currentUid;
    
    // Load data from services
    final messages = await _loadChatMessages(uid);
    final caregiver = await _loadPrimaryCaregiver(uid);
    final heartRate = await _loadLastHeartRate(uid);
    final isMonitoring = await _loadMonitoringStatus(uid);
    
    // Determine monitoring status text
    final statusText = _getMonitoringStatusText(
      isMonitoring: isMonitoring,
      hasHeartRate: heartRate != null,
    );
    
    return PatientAIChatState(
      isMonitoringActive: isMonitoring,
      heartRate: heartRate,
      messages: messages,
      caregiver: caregiver,
      isAITyping: false,
      inputMode: InputMode.voice,
      isRecording: false,
      monitoringStatusText: statusText,
    );
  }

  /// Load chat messages from AIChatService
  Future<List<ChatMessage>> _loadChatMessages(String? uid) async {
    if (uid == null) {
      return [
        ChatMessage(
          id: 'welcome',
          text: GuardianAIService.getWelcomeMessage(),
          sender: 'ai',
          timestamp: DateTime.now(),
          status: 'sent',
        ),
      ];
    }
    
    try {
      final messages = await AIChatService.instance.getMessages(uid);
      if (messages.isEmpty) {
        // First-time user - return welcome message
        return [
          ChatMessage(
            id: 'welcome',
            text: GuardianAIService.getWelcomeMessage(),
            sender: 'ai',
            timestamp: DateTime.now(),
            status: 'sent',
          ),
        ];
      }
      return messages;
    } catch (e) {
      debugPrint('[PatientAIChatDataProvider] Error loading messages: $e');
      return [
        ChatMessage(
          id: 'welcome',
          text: GuardianAIService.getWelcomeMessage(),
          sender: 'ai',
          timestamp: DateTime.now(),
          status: 'sent',
        ),
      ];
    }
  }

  /// Load primary caregiver from GuardianService
  Future<CaregiverPreview?> _loadPrimaryCaregiver(String? uid) async {
    if (uid == null) return null;
    
    try {
      final primary = await GuardianService.instance.getPrimaryGuardian(uid);
      if (primary != null) {
        return CaregiverPreview(
          id: primary.id,
          name: primary.name,
          relationship: primary.relation,
          isOnline: false,
        );
      }
    } catch (e) {
      debugPrint('[PatientAIChatDataProvider] Error loading primary caregiver: $e');
    }
    
    return null;
  }

  /// Load last known heart rate from VitalsRepository
  Future<int?> _loadLastHeartRate(String? uid) async {
    if (uid == null) return null;
    
    try {
      final latest = await _vitalsRepo.getLatestForUser(uid);
      if (latest != null) {
        return latest.heartRate;
      }
    } catch (e) {
      debugPrint('[PatientAIChatDataProvider] Error loading heart rate: $e');
    }
    
    return null;
  }

  /// Load monitoring status from AIChatService
  Future<bool> _loadMonitoringStatus(String? uid) async {
    if (uid == null) return false;
    
    try {
      return await AIChatService.instance.getMonitoringStatus(uid);
    } catch (e) {
      debugPrint('[PatientAIChatDataProvider] Error loading monitoring status: $e');
      return false;
    }
  }

  /// Get appropriate monitoring status text
  String _getMonitoringStatusText({
    required bool isMonitoring,
    required bool hasHeartRate,
  }) {
    if (!isMonitoring) {
      return 'Idle';
    }
    if (!hasHeartRate) {
      return 'No device';
    }
    return 'Monitoring';
  }

  /// Save a new chat message
  Future<void> saveMessage(ChatMessage message) async {
    final uid = _currentUid;
    if (uid == null) return;
    
    await AIChatService.instance.saveMessage(uid, message);
  }

  /// Update monitoring status
  Future<void> updateMonitoringStatus(bool isActive) async {
    final uid = _currentUid;
    if (uid == null) return;
    
    await AIChatService.instance.setMonitoringStatus(uid, isActive);
  }

  /// Clear chat history
  Future<void> clearChatHistory() async {
    final uid = _currentUid;
    if (uid == null) return;
    
    await AIChatService.instance.clearHistory(uid);
  }
}
