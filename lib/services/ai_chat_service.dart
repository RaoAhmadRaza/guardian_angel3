/// AIChatService - Persistent AI chat history service.
///
/// Uses SharedPreferences for simple JSON storage.
/// Stores chat messages for the AI assistant.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/patient_ai_chat/patient_ai_chat_state.dart';

/// Service for managing AI chat persistence.
class AIChatService {
  static const String _keyChatMessages = 'patient_ai_chat_messages';
  static const String _keyMonitoringStatus = 'patient_ai_monitoring_status';

  static AIChatService? _instance;
  static AIChatService get instance => _instance ??= AIChatService._();
  AIChatService._();

  /// Get chat messages for a patient
  Future<List<ChatMessage>> getMessages(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('${_keyChatMessages}_$patientId');
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => _chatMessageFromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      debugPrint('[AIChatService] Error loading messages: $e');
      return [];
    }
  }

  /// Save a chat message
  Future<bool> saveMessage(String patientId, ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await getMessages(patientId);
      
      // Remove existing if updating (same id)
      existing.removeWhere((m) => m.id == message.id);
      existing.add(message);

      final jsonStr = json.encode(existing.map((m) => _chatMessageToJson(m)).toList());
      await prefs.setString('${_keyChatMessages}_$patientId', jsonStr);
      debugPrint('[AIChatService] Saved message: ${message.id}');
      return true;
    } catch (e) {
      debugPrint('[AIChatService] Error saving message: $e');
      return false;
    }
  }

  /// Clear chat history for a patient
  Future<bool> clearHistory(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyChatMessages}_$patientId');
      debugPrint('[AIChatService] Cleared chat history for: $patientId');
      return true;
    } catch (e) {
      debugPrint('[AIChatService] Error clearing history: $e');
      return false;
    }
  }

  /// Get monitoring status
  Future<bool> getMonitoringStatus(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_keyMonitoringStatus}_$patientId') ?? false;
    } catch (e) {
      debugPrint('[AIChatService] Error loading monitoring status: $e');
      return false;
    }
  }

  /// Set monitoring status
  Future<bool> setMonitoringStatus(String patientId, bool isActive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_keyMonitoringStatus}_$patientId', isActive);
      debugPrint('[AIChatService] Set monitoring status: $patientId -> $isActive');
      return true;
    } catch (e) {
      debugPrint('[AIChatService] Error setting monitoring status: $e');
      return false;
    }
  }

  /// Convert ChatMessage to JSON
  Map<String, dynamic> _chatMessageToJson(ChatMessage message) => {
    'id': message.id,
    'text': message.text,
    'sender': message.sender,
    'timestamp': message.timestamp.toIso8601String(),
    'status': message.status,
  };

  /// Convert JSON to ChatMessage
  ChatMessage _chatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    text: json['text'] as String,
    sender: json['sender'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: json['status'] as String? ?? 'sent',
  );
}
