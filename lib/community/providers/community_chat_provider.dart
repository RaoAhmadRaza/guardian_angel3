/// Community Chat Provider
/// 
/// State management for the community chat room.
/// Manages messages, typing indicators, and real-time updates.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

/// State for the community chat
class CommunityChatState {
  /// List of messages
  final List<ChatMessage> messages;
  
  /// Current room info
  final ChatRoom? room;
  
  /// Loading state
  final bool isLoading;
  
  /// Error message if any
  final String? error;
  
  /// Is sending a message
  final bool isSending;
  
  /// Message being replied to
  final ChatMessage? replyingTo;
  
  /// Number of participants
  final int participantCount;
  
  const CommunityChatState({
    this.messages = const [],
    this.room,
    this.isLoading = true,
    this.error,
    this.isSending = false,
    this.replyingTo,
    this.participantCount = 0,
  });
  
  /// Initial loading state
  factory CommunityChatState.initial() {
    return const CommunityChatState(isLoading: true);
  }
  
  /// Error state
  factory CommunityChatState.error(String message) {
    return CommunityChatState(
      isLoading: false,
      error: message,
    );
  }
  
  /// Copy with new values
  CommunityChatState copyWith({
    List<ChatMessage>? messages,
    ChatRoom? room,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isSending,
    ChatMessage? replyingTo,
    bool clearReply = false,
    int? participantCount,
  }) {
    return CommunityChatState(
      messages: messages ?? this.messages,
      room: room ?? this.room,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSending: isSending ?? this.isSending,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      participantCount: participantCount ?? this.participantCount,
    );
  }
}

/// Provider for community chat state
class CommunityChatProvider extends ChangeNotifier {
  CommunityChatProvider._();
  
  static final CommunityChatProvider _instance = CommunityChatProvider._();
  static CommunityChatProvider get instance => _instance;
  
  final CommunityChatService _chatService = CommunityChatService.instance;
  
  /// Current state
  CommunityChatState _state = CommunityChatState.initial();
  CommunityChatState get state => _state;
  
  /// Stream subscription
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Initialize and join chat room
  Future<bool> initialize({
    required String userName,
    String? userAvatar,
  }) async {
    debugPrint('[CommunityChatProvider] Initializing...');
    
    _state = CommunityChatState.initial();
    notifyListeners();
    
    // Initialize chat service
    final success = await _chatService.initialize(
      userName: userName,
      userAvatar: userAvatar,
    );
    
    if (!success) {
      _state = CommunityChatState.error('Could not join chat room');
      notifyListeners();
      return false;
    }
    
    // Start listening to messages
    _subscribeToMessages();
    
    // Get room info
    final room = await _chatService.getRoomInfo();
    
    _state = _state.copyWith(
      isLoading: false,
      room: room,
      participantCount: room?.participantCount ?? 0,
      clearError: true,
    );
    notifyListeners();
    
    debugPrint('[CommunityChatProvider] Initialized');
    return true;
  }
  
  /// Subscribe to messages stream
  void _subscribeToMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService.messagesStream.listen(
      (messages) {
        _state = _state.copyWith(messages: messages);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[CommunityChatProvider] Messages stream error: $e');
      },
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGING
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Send a text message
  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty) return false;
    
    _state = _state.copyWith(isSending: true);
    notifyListeners();
    
    ChatMessage? sent;
    
    // Check if replying
    if (_state.replyingTo != null) {
      sent = await _chatService.sendReply(
        text: text,
        replyToId: _state.replyingTo!.id,
        replyToText: _state.replyingTo!.text,
      );
    } else {
      sent = await _chatService.sendMessage(text);
    }
    
    _state = _state.copyWith(
      isSending: false,
      clearReply: true,
    );
    notifyListeners();
    
    return sent != null;
  }
  
  /// Send an image message
  Future<bool> sendImage({
    required File imageFile,
    String? caption,
  }) async {
    _state = _state.copyWith(isSending: true);
    notifyListeners();
    
    final sent = await _chatService.sendImageMessage(
      imageFile: imageFile,
      caption: caption,
    );
    
    _state = _state.copyWith(isSending: false);
    notifyListeners();
    
    return sent != null;
  }
  
  /// Set message to reply to
  void setReplyingTo(ChatMessage? message) {
    _state = _state.copyWith(
      replyingTo: message,
      clearReply: message == null,
    );
    notifyListeners();
  }
  
  /// Cancel reply
  void cancelReply() {
    setReplyingTo(null);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Check if a message is from current user
  bool isMyMessage(ChatMessage message) {
    return _chatService.isMyMessage(message);
  }
  
  /// Get room ID
  String? get roomId => _chatService.currentRoomId;
  
  /// Get participant count
  int get participantCount => _chatService.participantCount;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Pause when not visible
  void pause() {
    _chatService.pause();
  }
  
  /// Resume when visible
  void resume() {
    _chatService.resume();
  }
  
  /// Leave room and clean up
  Future<void> leaveRoom() async {
    _messagesSubscription?.cancel();
    await _chatService.leaveRoom();
    _state = CommunityChatState.initial();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _chatService.leaveRoom();
    super.dispose();
  }
}
