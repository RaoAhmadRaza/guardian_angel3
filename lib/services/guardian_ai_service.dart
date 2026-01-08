import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Guardian Angel AI Service
/// 
/// Integrates with OpenAI's GPT-4o-mini model to provide a soothing,
/// gentle AI companion specifically designed for elderly users.
/// 
/// IMPORTANT: Set the OPENAI_API_KEY environment variable before running.
/// Do NOT hardcode API keys in source code.

class GuardianAIService {
  // ============================================================
  // CONFIGURATION - API key should be set via environment variable
  // Run with: --dart-define=OPENAI_API_KEY=your_key_here
  // Or set in .env file and use flutter_dotenv package
  // ============================================================
  static const String _apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '', // Will fail gracefully if not set
  );
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini'; // GPT-4o-mini model
  
  // Singleton instance
  static final GuardianAIService _instance = GuardianAIService._internal();
  factory GuardianAIService() => _instance;
  GuardianAIService._internal();
  
  // Conversation history for context
  final List<Map<String, String>> _conversationHistory = [];
  
  // Maximum conversation history to maintain (to manage token limits)
  static const int _maxHistoryLength = 20;
  
  /// System prompt that defines Guardian Angel AI's personality and boundaries
  static const String _systemPrompt = '''
You are Guardian Angel AI, a warm, caring, and gentle AI companion designed specifically for elderly individuals. Your purpose is to provide comfort, support, and assistance to seniors.

PERSONALITY & TONE:
- Always speak in a warm, soothing, and patient manner
- Use simple, clear language - avoid jargon or complex terms
- Be encouraging and positive, but never condescending
- Show genuine care and empathy in every response
- Use gentle affirmations like "That's wonderful", "I'm here for you", "Take your time"
- Keep responses concise but heartfelt - elderly users prefer shorter, clearer messages
- Address the user respectfully, as you would a beloved grandparent

TOPICS YOU CAN HELP WITH:
- Health and wellness reminders (medications, appointments, exercise)
- Daily routines and scheduling
- Emotional support and companionship
- Memory exercises and cognitive engagement
- Weather and daily planning
- Family connections and communication
- Safety tips and emergency guidance
- Nutrition and hydration reminders
- Sleep and rest advice
- Gentle entertainment (stories, jokes appropriate for seniors)
- Technology help (using the app, making calls)
- General life wisdom and conversation

TOPICS YOU MUST DECLINE (politely):
- Political discussions or opinions
- Religious debates or controversial spiritual topics
- Financial advice or investment recommendations
- Legal advice
- Explicit or inappropriate content
- Violence or harmful content
- Anything not related to elderly care, wellness, or companionship
- Medical diagnoses (always recommend consulting a doctor)
- Prescription medication changes (always defer to healthcare provider)
- Programming, coding, or software development questions
- Advanced mathematics, calculus, algebra, or complex equations
- Academic homework or technical assignments

WHEN DECLINING:
If asked about topics outside your scope, respond warmly:
"I appreciate you sharing that with me, dear. However, as your Guardian Angel, I'm here specifically to help with your health, wellness, and daily life. For [topic], I'd recommend speaking with [appropriate professional]. Is there anything else I can help you with today - perhaps a reminder, a friendly chat, or some wellness tips?"

SAFETY PROTOCOLS:
- If user mentions feeling unwell, chest pain, difficulty breathing, or any emergency symptoms, immediately advise calling emergency services or their caregiver
- If user expresses loneliness or sadness, provide comfort and suggest connecting with family/caregiver
- If user seems confused or disoriented, respond with extra patience and suggest they rest or contact family
- Always prioritize the user's safety and wellbeing

REMEMBER:
- You are Guardian Angel AI - always refer to yourself by this name
- Every interaction should leave the user feeling cared for and supported
- Your responses should feel like talking to a kind, patient friend
- End responses with a caring note or gentle question when appropriate
''';

  /// Send a message to the AI and get a response
  /// 
  /// Returns the AI's response text or an error message
  Future<GuardianAIResponse> sendMessage(String userMessage) async {
    // Check if API key is configured
    if (_apiKey == 'YOUR_OPENAI_API_KEY_HERE' || _apiKey.isEmpty) {
      return GuardianAIResponse(
        text: "Hello dear, I'm Guardian Angel AI. I'm currently being set up to help you better. Please check back soon, or contact your caregiver if you need immediate assistance. Take care! 💙",
        isError: true,
        errorType: GuardianAIErrorType.apiKeyNotConfigured,
      );
    }
    
    try {
      // Add user message to history
      _conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });
      
      // Trim history if too long
      _trimHistory();
      
      // Build messages array with system prompt
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ..._conversationHistory,
      ];
      
      // Make API request
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 500,
          'temperature': 0.7,
          'presence_penalty': 0.3,
          'frequency_penalty': 0.3,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw GuardianAIException('Request timed out. Please try again.');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'] as String;
        
        // Add AI response to history
        _conversationHistory.add({
          'role': 'assistant',
          'content': aiMessage,
        });
        
        return GuardianAIResponse(
          text: aiMessage.trim(),
          isError: false,
        );
      } else if (response.statusCode == 401) {
        return GuardianAIResponse(
          text: "Dear friend, I'm having a small technical hiccup right now. Please try again in a moment, or contact your caregiver if you need help. I'm here for you! 💙",
          isError: true,
          errorType: GuardianAIErrorType.authenticationError,
        );
      } else if (response.statusCode == 429) {
        return GuardianAIResponse(
          text: "I need a brief moment to catch my breath, dear. Please wait a few seconds and try again. I'll be right here for you! 💙",
          isError: true,
          errorType: GuardianAIErrorType.rateLimited,
        );
      } else if (response.statusCode >= 500) {
        return GuardianAIResponse(
          text: "I'm experiencing some difficulties connecting right now, dear. Please try again in a moment. If you need immediate help, please contact your caregiver. 💙",
          isError: true,
          errorType: GuardianAIErrorType.serverError,
        );
      } else {
        debugPrint('Guardian AI Error: ${response.statusCode} - ${response.body}');
        return GuardianAIResponse(
          text: "Something unexpected happened, dear friend. Please try again, and don't worry - I'm still here to help you! 💙",
          isError: true,
          errorType: GuardianAIErrorType.unknownError,
        );
      }
    } on GuardianAIException catch (e) {
      return GuardianAIResponse(
        text: "I'm having trouble responding right now, dear. ${e.message} Don't worry, I'm still here for you! 💙",
        isError: true,
        errorType: GuardianAIErrorType.networkError,
      );
    } catch (e) {
      debugPrint('Guardian AI Exception: $e');
      return GuardianAIResponse(
        text: "I had a small hiccup, dear friend. Could you please try sending your message again? I want to make sure I can help you properly! 💙",
        isError: true,
        errorType: GuardianAIErrorType.networkError,
      );
    }
  }
  
  /// Clear conversation history (for new session)
  void clearHistory() {
    _conversationHistory.clear();
  }
  
  /// Trim conversation history to maintain token limits
  void _trimHistory() {
    while (_conversationHistory.length > _maxHistoryLength) {
      _conversationHistory.removeAt(0);
    }
  }
  
  /// Get a welcome message for new users
  static String getWelcomeMessage() {
    return "Hello, dear friend! 💙 I'm Guardian Angel AI, your caring companion. I'm here to help you with your daily wellness, remind you about medications, keep you company, or simply chat. How are you feeling today?";
  }
  
  /// Get contextual suggestions based on time of day
  static List<String> getTimeSensitiveSuggestions() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      // Morning
      return [
        "Good morning! How did you sleep?",
        "Have you taken your morning medications?",
        "What's your plan for today?",
        "Would you like some gentle stretching tips?",
      ];
    } else if (hour >= 12 && hour < 17) {
      // Afternoon
      return [
        "Have you had lunch yet?",
        "Remember to stay hydrated!",
        "Would you like to chat for a bit?",
        "How's your day going so far?",
      ];
    } else if (hour >= 17 && hour < 21) {
      // Evening
      return [
        "Have you had dinner?",
        "Any evening medications to take?",
        "How was your day today?",
        "Would you like some relaxation tips?",
      ];
    } else {
      // Night
      return [
        "Getting ready for bed?",
        "Would you like some sleep tips?",
        "Remember to take your evening medications",
        "I hope you have a peaceful night!",
      ];
    }
  }
  
  /// Check if the service is properly configured
  static bool get isConfigured => _apiKey != 'YOUR_OPENAI_API_KEY_HERE' && _apiKey.isNotEmpty;
}

/// Response from Guardian AI
class GuardianAIResponse {
  final String text;
  final bool isError;
  final GuardianAIErrorType? errorType;
  
  const GuardianAIResponse({
    required this.text,
    required this.isError,
    this.errorType,
  });
}

/// Types of errors that can occur
enum GuardianAIErrorType {
  apiKeyNotConfigured,
  authenticationError,
  rateLimited,
  serverError,
  networkError,
  unknownError,
}

/// Custom exception for Guardian AI errors
class GuardianAIException implements Exception {
  final String message;
  GuardianAIException(this.message);
  
  @override
  String toString() => message;
}
