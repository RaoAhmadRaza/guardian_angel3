/// Community Chat Service
/// 
/// Real-time chat service for location-based community.
/// Uses Firestore streams for instant message updates.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../repositories/community_firestore_repository.dart';
import 'community_location_service.dart';

/// Service for managing community chat
class CommunityChatService {
  CommunityChatService._();
  
  static final CommunityChatService _instance = CommunityChatService._();
  static CommunityChatService get instance => _instance;
  
  final CommunityFirestoreRepository _repository = CommunityFirestoreRepository.instance;
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Current chat room
  ChatRoom? _currentRoom;
  ChatRoom? get currentRoom => _currentRoom;
  
  /// Current room ID (geohash prefix)
  String? _currentRoomId;
  String? get currentRoomId => _currentRoomId;
  
  /// Messages stream subscription
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  
  /// Messages stream controller
  final StreamController<List<ChatMessage>> _messagesController = 
      StreamController<List<ChatMessage>>.broadcast();
  
  /// Stream of messages
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;
  
  /// Cached messages
  List<ChatMessage> _cachedMessages = [];
  List<ChatMessage> get cachedMessages => _cachedMessages;
  
  /// Current user info (cached for messages)
  String? _userName;
  String? _userAvatar;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Initialize chat and join room based on location
  Future<bool> initialize({
    required String userName,
    String? userAvatar,
  }) async {
    debugPrint('[CommunityChatService] Initializing...');
    
    _userName = userName;
    _userAvatar = userAvatar;
    
    // Get current location
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      debugPrint('[CommunityChatService] Cannot initialize - no location');
      return false;
    }
    
    // Generate geohash and get room ID
    final geohash = GeoHashEncoder.encode(
      position.latitude, 
      position.longitude, 
      precision: 6,
    );
    _currentRoomId = geohash.substring(0, 4);
    
    // Get or create room
    _currentRoom = await _repository.getOrCreateChatRoom(geohash);
    if (_currentRoom == null) {
      debugPrint('[CommunityChatService] Failed to get/create room');
      return false;
    }
    
    // Update participant count
    await _repository.updateParticipantCount(_currentRoomId!, 1);
    
    // Start listening for messages
    _startMessagesStream();
    
    debugPrint('[CommunityChatService] Joined room: $_currentRoomId');
    return true;
  }
  
  /// Start streaming messages from Firestore
  void _startMessagesStream() {
    if (_currentRoomId == null) return;
    
    _messagesSubscription?.cancel();
    _messagesSubscription = _repository.streamMessages(_currentRoomId!).listen(
      (messages) {
        _cachedMessages = messages;
        _messagesController.add(messages);
        debugPrint('[CommunityChatService] Received ${messages.length} messages');
      },
      onError: (e) {
        debugPrint('[CommunityChatService] Stream error: $e');
      },
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGING
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Send a text message
  Future<ChatMessage?> sendMessage(String text) async {
    if (_currentRoomId == null || _userName == null) {
      debugPrint('[CommunityChatService] Cannot send - not initialized');
      return null;
    }
    
    if (text.trim().isEmpty) return null;
    
    return _repository.sendMessage(
      roomId: _currentRoomId!,
      text: text.trim(),
      senderName: _userName!,
      senderAvatar: _userAvatar,
    );
  }
  
  /// Send a message with image
  Future<ChatMessage?> sendImageMessage({
    required File imageFile,
    String? caption,
  }) async {
    if (_currentRoomId == null || _userName == null) return null;
    
    // Upload image
    final imageUrl = await _uploadImage(imageFile);
    if (imageUrl == null) {
      debugPrint('[CommunityChatService] Image upload failed');
      return null;
    }
    
    return _repository.sendMessage(
      roomId: _currentRoomId!,
      text: caption ?? '',
      imageUrl: imageUrl,
      senderName: _userName!,
      senderAvatar: _userAvatar,
      type: ChatMessageType.image,
    );
  }
  
  /// Send a reply to another message
  Future<ChatMessage?> sendReply({
    required String text,
    required String replyToId,
    required String replyToText,
  }) async {
    if (_currentRoomId == null || _userName == null) return null;
    
    return _repository.sendMessage(
      roomId: _currentRoomId!,
      text: text.trim(),
      senderName: _userName!,
      senderAvatar: _userAvatar,
      replyToId: replyToId,
      replyToText: replyToText.length > 50 
          ? '${replyToText.substring(0, 50)}...' 
          : replyToText,
    );
  }
  
  /// Upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    try {
      final fileName = 'community_chat/${_currentRoomId}_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      if (uploadTask.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      
      return null;
    } catch (e) {
      debugPrint('[CommunityChatService] Image upload error: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Check if a message is from the current user
  bool isMyMessage(ChatMessage message) {
    final uid = _auth.currentUser?.uid;
    return uid != null && message.senderUid == uid;
  }
  
  /// Get room info
  Future<ChatRoom?> getRoomInfo() async {
    if (_currentRoomId == null) return null;
    return _repository.getChatRoom(_currentRoomId!);
  }
  
  /// Get number of participants
  int get participantCount => _currentRoom?.participantCount ?? 0;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Leave the current room and clean up
  Future<void> leaveRoom() async {
    if (_currentRoomId != null) {
      await _repository.updateParticipantCount(_currentRoomId!, -1);
    }
    
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _cachedMessages = [];
    _currentRoom = null;
    _currentRoomId = null;
    
    debugPrint('[CommunityChatService] Left room');
  }
  
  /// Dispose resources
  void dispose() {
    leaveRoom();
    _messagesController.close();
  }
  
  /// Pause streaming
  void pause() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }
  
  /// Resume streaming
  void resume() {
    if (_currentRoomId != null && _messagesSubscription == null) {
      _startMessagesStream();
    }
  }
}
