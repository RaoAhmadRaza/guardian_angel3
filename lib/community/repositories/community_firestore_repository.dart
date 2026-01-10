/// Community Firestore Repository
/// 
/// Core Firestore operations for community feature.
/// Handles all database reads/writes for users, posts, and chats.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import '../services/community_location_service.dart';

/// Repository for community Firestore operations
class CommunityFirestoreRepository {
  CommunityFirestoreRepository._();
  
  static final CommunityFirestoreRepository _instance = CommunityFirestoreRepository._();
  static CommunityFirestoreRepository get instance => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  
  /// Collection names
  static const String _usersCollection = 'community_users';
  static const String _postsCollection = 'community_posts';
  static const String _chatsCollection = 'community_chats';
  
  /// Current user UID
  String? get _currentUid => _auth.currentUser?.uid;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // USER OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get a specific user by UID
  Future<CommunityUser?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (!doc.exists) return null;
      return CommunityUser.fromFirestore(doc.data()!, uid);
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to get user: $e');
      return null;
    }
  }
  
  /// Get users within a radius using geohash prefix queries
  /// For 10km radius, we query with 4-character geohash prefix
  Future<List<CommunityUser>> getUsersNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // Generate geohash for current location
      final centerGeohash = GeoHashEncoder.encode(latitude, longitude, precision: 6);
      
      // For 10km radius, use 4-character prefix (covers ~40km x 20km)
      // This is broader than needed but we filter precisely afterward
      final prefix = centerGeohash.substring(0, 4);
      
      // Query users with matching geohash prefix
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('geohash', isGreaterThanOrEqualTo: prefix)
          .where('geohash', isLessThan: '${prefix}z')
          .where('visibility', isEqualTo: CommunityVisibility.visible.name)
          .where('isPatient', isEqualTo: true)
          .limit(100)
          .get();
      
      // Parse and filter by exact distance
      final users = <CommunityUser>[];
      for (final doc in querySnapshot.docs) {
        final user = CommunityUser.fromFirestore(doc.data(), doc.id);
        
        // Skip current user
        if (user.uid == _currentUid) continue;
        
        // Calculate exact distance
        final distance = _locationService.calculateDistance(
          latitude, longitude,
          user.latitude, user.longitude,
        );
        
        // Only include if within radius
        if (distance <= radiusKm) {
          users.add(user);
        }
      }
      
      debugPrint('[CommunityRepo] Found ${users.length} nearby users');
      return users;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to get nearby users: $e');
      return [];
    }
  }
  
  /// Stream of nearby users (real-time updates)
  Stream<List<CommunityUser>> streamUsersNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) {
    final centerGeohash = GeoHashEncoder.encode(latitude, longitude, precision: 6);
    final prefix = centerGeohash.substring(0, 4);
    
    return _firestore
        .collection(_usersCollection)
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '${prefix}z')
        .where('visibility', isEqualTo: CommunityVisibility.visible.name)
        .where('isPatient', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final users = <CommunityUser>[];
          for (final doc in snapshot.docs) {
            final user = CommunityUser.fromFirestore(doc.data(), doc.id);
            if (user.uid == _currentUid) continue;
            
            final distance = _locationService.calculateDistance(
              latitude, longitude,
              user.latitude, user.longitude,
            );
            
            if (distance <= radiusKm) {
              users.add(user);
            }
          }
          return users;
        });
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // POST OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create a new post
  Future<CommunityPost?> createPost({
    required String content,
    String? imageUrl,
    required String authorName,
    String? authorAvatar,
    required double latitude,
    required double longitude,
  }) async {
    final uid = _currentUid;
    if (uid == null) return null;
    
    try {
      final geohash = GeoHashEncoder.encode(latitude, longitude, precision: 6);
      final geoPoint = GeoPoint(latitude, longitude);
      
      final postData = {
        'authorUid': uid,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'latitude': latitude,
        'longitude': longitude,
        'location': geoPoint,
        'geohash': geohash,
        'content': content,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'likes': <String>[],
        'commentCount': 0,
        'isFlagged': false,
      };
      
      final docRef = await _firestore.collection(_postsCollection).add(postData);
      
      debugPrint('[CommunityRepo] Created post: ${docRef.id}');
      
      // Return the created post
      return CommunityPost(
        id: docRef.id,
        authorUid: uid,
        authorName: authorName,
        authorAvatar: authorAvatar,
        latitude: latitude,
        longitude: longitude,
        location: geoPoint,
        geohash: geohash,
        content: content,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to create post: $e');
      return null;
    }
  }
  
  /// Get posts within radius
  Future<List<CommunityPost>> getPostsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 50,
  }) async {
    try {
      final centerGeohash = GeoHashEncoder.encode(latitude, longitude, precision: 6);
      final prefix = centerGeohash.substring(0, 4);
      
      final querySnapshot = await _firestore
          .collection(_postsCollection)
          .where('geohash', isGreaterThanOrEqualTo: prefix)
          .where('geohash', isLessThan: '${prefix}z')
          .orderBy('geohash')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      final posts = <CommunityPost>[];
      for (final doc in querySnapshot.docs) {
        final post = CommunityPost.fromFirestore(doc.data(), doc.id);
        
        // Calculate exact distance
        final distance = _locationService.calculateDistance(
          latitude, longitude,
          post.latitude, post.longitude,
        );
        
        if (distance <= radiusKm) {
          post.distanceKm = distance;
          posts.add(post);
        }
      }
      
      // Sort by creation time
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      debugPrint('[CommunityRepo] Found ${posts.length} nearby posts');
      return posts;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to get nearby posts: $e');
      return [];
    }
  }
  
  /// Stream of nearby posts (real-time updates)
  Stream<List<CommunityPost>> streamPostsNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    int limit = 50,
  }) {
    final centerGeohash = GeoHashEncoder.encode(latitude, longitude, precision: 6);
    final prefix = centerGeohash.substring(0, 4);
    
    return _firestore
        .collection(_postsCollection)
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: '${prefix}z')
        .orderBy('geohash')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final posts = <CommunityPost>[];
          for (final doc in snapshot.docs) {
            final post = CommunityPost.fromFirestore(doc.data(), doc.id);
            
            final distance = _locationService.calculateDistance(
              latitude, longitude,
              post.latitude, post.longitude,
            );
            
            if (distance <= radiusKm) {
              post.distanceKm = distance;
              posts.add(post);
            }
          }
          
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }
  
  /// Like a post
  Future<bool> likePost(String postId) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    try {
      await _firestore.collection(_postsCollection).doc(postId).update({
        'likes': FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(1),
      });
      return true;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to like post: $e');
      return false;
    }
  }
  
  /// Unlike a post
  Future<bool> unlikePost(String postId) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    try {
      await _firestore.collection(_postsCollection).doc(postId).update({
        'likes': FieldValue.arrayRemove([uid]),
        'likeCount': FieldValue.increment(-1),
      });
      return true;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to unlike post: $e');
      return false;
    }
  }
  
  /// Delete a post (only author can delete)
  Future<bool> deletePost(String postId) async {
    final uid = _currentUid;
    if (uid == null) return false;
    
    try {
      final doc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!doc.exists) return false;
      
      final authorUid = doc.data()?['authorUid'] as String?;
      if (authorUid != uid) {
        debugPrint('[CommunityRepo] Cannot delete - not author');
        return false;
      }
      
      await _firestore.collection(_postsCollection).doc(postId).delete();
      return true;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to delete post: $e');
      return false;
    }
  }
  
  /// Flag/report a post
  Future<bool> flagPost(String postId) async {
    try {
      await _firestore.collection(_postsCollection).doc(postId).update({
        'isFlagged': true,
      });
      return true;
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to flag post: $e');
      return false;
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get or create a chat room for a geohash area
  /// Room ID is based on 4-char geohash prefix (covers ~40km area)
  Future<ChatRoom?> getOrCreateChatRoom(String geohash) async {
    final roomId = geohash.substring(0, 4);
    
    try {
      final doc = await _firestore.collection(_chatsCollection).doc(roomId).get();
      
      if (doc.exists) {
        return ChatRoom.fromFirestore(doc.data()!, roomId);
      }
      
      // Create new room
      final roomData = {
        'name': 'Local Community',
        'description': 'Chat with people in your area',
        'participantCount': 1,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection(_chatsCollection).doc(roomId).set(roomData);
      
      return ChatRoom(
        id: roomId,
        name: 'Local Community',
        description: 'Chat with people in your area',
        participantCount: 1,
      );
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to get/create chat room: $e');
      return null;
    }
  }
  
  /// Send a message to a chat room
  Future<ChatMessage?> sendMessage({
    required String roomId,
    required String text,
    String? imageUrl,
    required String senderName,
    String? senderAvatar,
    ChatMessageType type = ChatMessageType.text,
    String? replyToId,
    String? replyToText,
  }) async {
    final uid = _currentUid;
    if (uid == null) return null;
    
    try {
      final messageData = {
        'senderUid': uid,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'text': text,
        'imageUrl': imageUrl,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'replyToId': replyToId,
        'replyToText': replyToText,
      };
      
      final docRef = await _firestore
          .collection(_chatsCollection)
          .doc(roomId)
          .collection('messages')
          .add(messageData);
      
      // Update room's last message
      await _firestore.collection(_chatsCollection).doc(roomId).update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      
      return ChatMessage(
        id: docRef.id,
        senderUid: uid,
        senderName: senderName,
        senderAvatar: senderAvatar,
        text: text,
        imageUrl: imageUrl,
        type: type,
        createdAt: DateTime.now(),
        replyToId: replyToId,
        replyToText: replyToText,
      );
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to send message: $e');
      return null;
    }
  }
  
  /// Stream of messages in a chat room (real-time)
  Stream<List<ChatMessage>> streamMessages(String roomId, {int limit = 100}) {
    return _firestore
        .collection(_chatsCollection)
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
              .toList()
              .reversed
              .toList(); // Reverse to get oldest first for display
        });
  }
  
  /// Get chat room details
  Future<ChatRoom?> getChatRoom(String roomId) async {
    try {
      final doc = await _firestore.collection(_chatsCollection).doc(roomId).get();
      if (!doc.exists) return null;
      return ChatRoom.fromFirestore(doc.data()!, roomId);
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to get chat room: $e');
      return null;
    }
  }
  
  /// Update participant count when joining/leaving
  Future<void> updateParticipantCount(String roomId, int delta) async {
    try {
      await _firestore.collection(_chatsCollection).doc(roomId).update({
        'participantCount': FieldValue.increment(delta),
      });
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to update participant count: $e');
    }
  }
}
