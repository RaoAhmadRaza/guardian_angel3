/// Community Post Service
/// 
/// High-level service for managing community posts.
/// Handles post creation, reading, liking, and real-time updates.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../repositories/community_firestore_repository.dart';
import 'community_location_service.dart';

/// Service for managing community posts
class CommunityPostService {
  CommunityPostService._();
  
  static final CommunityPostService _instance = CommunityPostService._();
  static CommunityPostService get instance => _instance;
  
  final CommunityFirestoreRepository _repository = CommunityFirestoreRepository.instance;
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Current location cache
  Position? _currentPosition;
  
  /// Active posts stream subscription
  StreamSubscription<List<CommunityPost>>? _postsSubscription;
  
  /// Posts stream controller
  final StreamController<List<CommunityPost>> _postsController = 
      StreamController<List<CommunityPost>>.broadcast();
  
  /// Stream of nearby posts
  Stream<List<CommunityPost>> get postsStream => _postsController.stream;
  
  /// Cached posts
  List<CommunityPost> _cachedPosts = [];
  List<CommunityPost> get cachedPosts => _cachedPosts;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Initialize the service and start listening for posts
  Future<bool> initialize() async {
    debugPrint('[CommunityPostService] Initializing...');
    
    // Get current location
    _currentPosition = await _locationService.getCurrentLocation();
    if (_currentPosition == null) {
      debugPrint('[CommunityPostService] Cannot initialize - no location');
      return false;
    }
    
    // Start listening for nearby posts
    _startPostsStream();
    
    debugPrint('[CommunityPostService] Initialized');
    return true;
  }
  
  /// Start streaming posts from Firestore
  void _startPostsStream() {
    if (_currentPosition == null) return;
    
    _postsSubscription?.cancel();
    _postsSubscription = _repository.streamPostsNearby(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: 10.0,
    ).listen(
      (posts) {
        _cachedPosts = posts;
        _postsController.add(posts);
        debugPrint('[CommunityPostService] Received ${posts.length} posts');
      },
      onError: (e) {
        debugPrint('[CommunityPostService] Stream error: $e');
      },
    );
  }
  
  /// Refresh location and restart stream
  Future<void> refreshLocation() async {
    _currentPosition = await _locationService.getCurrentLocation(forceRefresh: true);
    if (_currentPosition != null) {
      _startPostsStream();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // POST CREATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create a new post
  Future<CommunityPost?> createPost({
    required String content,
    File? imageFile,
    required String authorName,
    String? authorAvatar,
  }) async {
    // Get current location
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      debugPrint('[CommunityPostService] Cannot create post - no location');
      return null;
    }
    
    String? imageUrl;
    
    // Upload image if provided
    if (imageFile != null) {
      imageUrl = await _uploadImage(imageFile);
      if (imageUrl == null) {
        debugPrint('[CommunityPostService] Image upload failed');
        // Continue without image
      }
    }
    
    // Create post in Firestore
    return _repository.createPost(
      content: content,
      imageUrl: imageUrl,
      authorName: authorName,
      authorAvatar: authorAvatar,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
  
  /// Upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    try {
      final fileName = 'community_posts/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      debugPrint('[CommunityPostService] Image upload error: $e');
      return null;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // POST INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Toggle like on a post
  Future<bool> toggleLike(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    // Check if already liked
    final post = _cachedPosts.firstWhere(
      (p) => p.id == postId,
      orElse: () => CommunityPost(
        id: '', authorUid: '', authorName: '', 
        latitude: 0, longitude: 0, 
        location: const GeoPoint(0, 0),
        geohash: '', content: '', createdAt: DateTime.now(),
      ),
    );
    
    if (post.id.isEmpty) return false;
    
    if (post.isLikedBy(uid)) {
      return _repository.unlikePost(postId);
    } else {
      return _repository.likePost(postId);
    }
  }
  
  /// Check if current user liked a post
  bool isLiked(String postId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final post = _cachedPosts.firstWhere(
      (p) => p.id == postId,
      orElse: () => CommunityPost(
        id: '', authorUid: '', authorName: '', 
        latitude: 0, longitude: 0, 
        location: const GeoPoint(0, 0),
        geohash: '', content: '', createdAt: DateTime.now(),
      ),
    );
    
    return post.isLikedBy(uid);
  }
  
  /// Delete a post
  Future<bool> deletePost(String postId) async {
    return _repository.deletePost(postId);
  }
  
  /// Report a post
  Future<bool> reportPost(String postId) async {
    return _repository.flagPost(postId);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get posts one-time (not streaming)
  Future<List<CommunityPost>> getPosts() async {
    if (_currentPosition == null) {
      _currentPosition = await _locationService.getCurrentLocation();
    }
    
    if (_currentPosition == null) return [];
    
    return _repository.getPostsNearby(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: 10.0,
    );
  }
  
  /// Get posts by a specific user
  Future<List<CommunityPost>> getPostsByUser(String uid) async {
    // Filter cached posts by user
    return _cachedPosts.where((p) => p.authorUid == uid).toList();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Dispose resources
  void dispose() {
    _postsSubscription?.cancel();
    _postsController.close();
  }
  
  /// Pause streaming (when screen is not visible)
  void pause() {
    _postsSubscription?.cancel();
    _postsSubscription = null;
  }
  
  /// Resume streaming
  void resume() {
    if (_currentPosition != null && _postsSubscription == null) {
      _startPostsStream();
    }
  }
}
