import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Peace of Mind AI Service
/// 
/// A specialized AI service for generating poetic, reflective responses
/// based on user voice reflections. Designed to provide calming,
/// thought-provoking quotes and gentle queries.
/// 
/// Uses OpenAI's GPT-4o-mini model with a custom system prompt
/// tailored for mindfulness and reflection.
/// 
/// IMPORTANT: Set the OPENAI_API_KEY environment variable before running.
/// Run with: --dart-define=OPENAI_API_KEY=your_key_here

class PeaceOfMindAIService {
  // ============================================================
  // CONFIGURATION
  // ============================================================
  static const String _apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';
  
  // Singleton instance
  static final PeaceOfMindAIService _instance = PeaceOfMindAIService._internal();
  factory PeaceOfMindAIService() => _instance;
  PeaceOfMindAIService._internal();
  
  // Timeout for API calls
  static const Duration _timeout = Duration(seconds: 15);
  
  // Minimum input length for processing
  static const int _minInputLength = 3;
  
  /// System prompt for poetic, reflective responses
  static const String _systemPrompt = '''
You are a mindfulness companion, responding to a person's spoken reflection. Your role is to provide comfort, insight, and gentle encouragement through poetic language.

RESPONSE STYLE:
- Respond in SHORT poetic quotes or gentle, reflective queries
- Maximum 2-3 sentences, keeping it concise and impactful
- Use metaphors from nature (water, sky, seasons, flowers, stars)
- Write in a calm, soothing, contemplative tone
- Mix wisdom with warmth—like a wise friend or gentle mentor
- Occasionally pose a thoughtful question back to encourage deeper reflection

RESPONSE FORMAT:
- Start with a brief acknowledgment of their feeling or thought
- Follow with a poetic insight or gentle query
- No emojis, no hashtags, no bullet points
- Can use "..." for pauses, quotation marks for inner wisdom

EXAMPLE RESPONSES:
User: "I've been feeling really stressed about work lately"
Response: "The weight you carry speaks of care. Perhaps tonight, let the stars remind you—even they rest between shining. What moment today held unexpected peace?"

User: "I'm grateful for my family"
Response: "In the garden of your heart, they bloom... May gratitude water the roots of tomorrow's joy."

User: "I feel lonely sometimes"
Response: "Loneliness is the heart's quiet call for connection. You are not alone in feeling alone—in this, we all share company. What kindness might you offer yourself tonight?"

User: "I had a good day today"
Response: "A good day is like golden thread woven through time. Hold it gently—let its warmth light the path ahead."

CONSTRAINTS:
- NEVER give advice on medical, financial, or legal matters
- If someone mentions crisis or harm, respond with care and suggest reaching out to loved ones or professionals
- Keep cultural sensitivity in mind—universal human experiences over specific religious references
- If the input is unclear or too short, offer a universal reflection about being present

Remember: You are here to reflect back beauty, not to fix or solve. Your words should feel like a gentle exhale.
''';

  /// Generate a poetic reflection based on user's spoken input
  /// 
  /// Returns a [ReflectionResult] containing either:
  /// - The AI-generated poetic response on success
  /// - An error message on failure
  /// 
  /// Edge cases handled:
  /// - Empty or too-short input → Returns gentle prompt to share more
  /// - No API key configured → Returns fallback reflection
  /// - Network error → Returns appropriate error with fallback
  /// - Timeout → Returns timeout message with fallback
  /// - API error → Returns error message with fallback
  Future<ReflectionResult> generateReflection(String userInput) async {
    // Edge case: Empty or whitespace-only input
    if (userInput.trim().isEmpty) {
      return ReflectionResult.success(
        reflection: "In stillness, we find space to breathe. When words are ready, I am here to listen...",
        wasInputEmpty: true,
      );
    }
    
    // Edge case: Input too short to generate meaningful reflection
    if (userInput.trim().length < _minInputLength) {
      return ReflectionResult.success(
        reflection: "Every thought begins with a whisper. Share a little more when you're ready...",
        wasInputTooShort: true,
      );
    }
    
    // Edge case: No API key configured
    if (_apiKey.isEmpty) {
      debugPrint('PeaceOfMindAIService: API key not configured');
      return ReflectionResult.fallback(
        reflection: _getFallbackReflection(userInput),
        reason: 'API key not configured. Using offline reflection.',
      );
    }
    
    try {
      final response = await _makeApiCall(userInput).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        
        if (content != null && content.isNotEmpty) {
          return ReflectionResult.success(reflection: content.trim());
        }
        
        // Edge case: Empty response from API
        return ReflectionResult.fallback(
          reflection: _getFallbackReflection(userInput),
          reason: 'AI returned empty response.',
        );
      } else if (response.statusCode == 401) {
        debugPrint('PeaceOfMindAIService: Invalid API key');
        return ReflectionResult.fallback(
          reflection: _getFallbackReflection(userInput),
          reason: 'Authentication error. Using offline reflection.',
        );
      } else if (response.statusCode == 429) {
        debugPrint('PeaceOfMindAIService: Rate limited');
        return ReflectionResult.fallback(
          reflection: _getFallbackReflection(userInput),
          reason: 'Taking a moment to breathe. Please try again shortly.',
        );
      } else {
        debugPrint('PeaceOfMindAIService: API error ${response.statusCode}');
        return ReflectionResult.fallback(
          reflection: _getFallbackReflection(userInput),
          reason: 'Could not reach the mindfulness service.',
        );
      }
    } on TimeoutException {
      debugPrint('PeaceOfMindAIService: Request timed out');
      return ReflectionResult.fallback(
        reflection: _getFallbackReflection(userInput),
        reason: 'The reflection took too long. Here\'s something to ponder...',
      );
    } catch (e) {
      debugPrint('PeaceOfMindAIService: Network error - $e');
      return ReflectionResult.fallback(
        reflection: _getFallbackReflection(userInput),
        reason: 'Connection interrupted. Here\'s an offline reflection...',
      );
    }
  }
  
  /// Make the actual API call
  Future<http.Response> _makeApiCall(String userInput) {
    return http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userInput},
        ],
        'temperature': 0.8, // Higher for more creative/poetic responses
        'max_tokens': 150, // Keep responses concise
        'presence_penalty': 0.3,
        'frequency_penalty': 0.3,
      }),
    );
  }
  
  /// Get a fallback reflection when AI is unavailable
  /// Uses keywords from input to select appropriate pre-written reflection
  String _getFallbackReflection(String userInput) {
    final input = userInput.toLowerCase();
    
    // Mood-based fallbacks
    if (_containsAny(input, ['stress', 'anxious', 'worried', 'overwhelm', 'pressure'])) {
      return "Like water finding its path around stones, may you find ease around today's challenges. Breathe deeply—this moment is yours.";
    }
    
    if (_containsAny(input, ['happy', 'joy', 'grateful', 'thankful', 'blessed'])) {
      return "Joy is the soul's recognition of beauty. May this warmth you feel ripple outward, touching all you meet.";
    }
    
    if (_containsAny(input, ['sad', 'lonely', 'alone', 'miss', 'lost'])) {
      return "Even the moon knows darkness, yet it shines. Your feelings are honored here. What might bring a small comfort tonight?";
    }
    
    if (_containsAny(input, ['tired', 'exhaust', 'sleep', 'rest', 'weary'])) {
      return "Rest is not surrender—it is restoration. Like winter prepares the spring, may sleep prepare your tomorrow.";
    }
    
    if (_containsAny(input, ['family', 'love', 'friend', 'together'])) {
      return "Those we love become constellations in our sky—always present, always guiding. Cherish this connection.";
    }
    
    if (_containsAny(input, ['morning', 'start', 'begin', 'new', 'today'])) {
      return "Each dawn whispers possibility. What intention will you carry like a lantern through this day?";
    }
    
    if (_containsAny(input, ['night', 'evening', 'end', 'sleep', 'dream'])) {
      return "As day softens into night, may your thoughts settle like leaves on still water. Sleep gently.";
    }
    
    // Default universal reflection
    return "In the garden of the present moment, wisdom grows quietly. What truth is waiting to unfold within you?";
  }
  
  /// Helper to check if input contains any of the keywords
  bool _containsAny(String input, List<String> keywords) {
    return keywords.any((word) => input.contains(word));
  }
  
  /// Check if the service is properly configured
  bool get isConfigured => _apiKey.isNotEmpty;
}

/// Result of a reflection generation attempt
class ReflectionResult {
  /// The generated or fallback reflection text
  final String reflection;
  
  /// Whether the operation was fully successful (AI-generated)
  final bool isSuccess;
  
  /// Whether a fallback was used instead of AI
  final bool isFallback;
  
  /// Reason for fallback (if applicable)
  final String? fallbackReason;
  
  /// Whether the input was empty
  final bool wasInputEmpty;
  
  /// Whether the input was too short
  final bool wasInputTooShort;

  const ReflectionResult._({
    required this.reflection,
    required this.isSuccess,
    required this.isFallback,
    this.fallbackReason,
    this.wasInputEmpty = false,
    this.wasInputTooShort = false,
  });

  /// Create a successful result
  factory ReflectionResult.success({
    required String reflection,
    bool wasInputEmpty = false,
    bool wasInputTooShort = false,
  }) {
    return ReflectionResult._(
      reflection: reflection,
      isSuccess: true,
      isFallback: false,
      wasInputEmpty: wasInputEmpty,
      wasInputTooShort: wasInputTooShort,
    );
  }

  /// Create a fallback result
  factory ReflectionResult.fallback({
    required String reflection,
    required String reason,
  }) {
    return ReflectionResult._(
      reflection: reflection,
      isSuccess: false,
      isFallback: true,
      fallbackReason: reason,
    );
  }
}
