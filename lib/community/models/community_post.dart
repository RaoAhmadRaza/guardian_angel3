/// Community Post Model
/// 
/// Represents a post in the location-based community feed.
/// Posts are geo-tagged and only visible to users within 10km radius.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Community post with location data
class CommunityPost {
  /// Unique post ID (Firestore document ID)
  final String id;
  
  /// Author's Firebase UID
  final String authorUid;
  
  /// Author's display name (cached for performance)
  final String authorName;
  
  /// Author's avatar URL (cached)
  final String? authorAvatar;
  
  /// Post latitude (author's location at time of posting)
  final double latitude;
  
  /// Post longitude
  final double longitude;
  
  /// GeoPoint for Firestore geo-queries
  final GeoPoint location;
  
  /// Geohash for efficient radius queries
  final String geohash;
  
  /// Post text content
  final String content;
  
  /// Optional image URL (uploaded to Firebase Storage)
  final String? imageUrl;
  
  /// When the post was created
  final DateTime createdAt;
  
  /// Number of likes
  final int likeCount;
  
  /// List of user UIDs who liked this post
  final List<String> likes;
  
  /// Number of comments
  final int commentCount;
  
  /// Whether the post is flagged/reported
  final bool isFlagged;
  
  /// Distance from current user (calculated at runtime, not stored)
  double? distanceKm;
  
  CommunityPost({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorAvatar,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.geohash,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.likes = const [],
    this.commentCount = 0,
    this.isFlagged = false,
    this.distanceKm,
  });
  
  /// Create from Firestore document
  factory CommunityPost.fromFirestore(Map<String, dynamic> data, String docId) {
    final geoPoint = data['location'] as GeoPoint?;
    final likesList = (data['likes'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [];
    
    return CommunityPost(
      id: docId,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Anonymous',
      authorAvatar: data['authorAvatar'] as String?,
      latitude: data['latitude'] as double? ?? geoPoint?.latitude ?? 0.0,
      longitude: data['longitude'] as double? ?? geoPoint?.longitude ?? 0.0,
      location: geoPoint ?? const GeoPoint(0, 0),
      geohash: data['geohash'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] as int? ?? likesList.length,
      likes: likesList,
      commentCount: data['commentCount'] as int? ?? 0,
      isFlagged: data['isFlagged'] as bool? ?? false,
    );
  }
  
  /// Convert to Firestore document for creation
  Map<String, dynamic> toFirestore() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'geohash': geohash,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likes': likes,
      'commentCount': commentCount,
      'isFlagged': isFlagged,
    };
  }
  
  /// Check if a user has liked this post
  bool isLikedBy(String uid) => likes.contains(uid);
  
  /// Alias for authorAvatar for API consistency
  String? get authorAvatarUrl => authorAvatar;
  
  /// Check if current user liked this post (must be set externally)
  bool likedByMe = false;
  
  /// Create a copy with updated fields
  CommunityPost copyWith({
    String? authorName,
    String? authorAvatar,
    String? content,
    String? imageUrl,
    int? likeCount,
    List<String>? likes,
    int? commentCount,
    bool? isFlagged,
    double? distanceKm,
  }) {
    return CommunityPost(
      id: id,
      authorUid: authorUid,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      latitude: latitude,
      longitude: longitude,
      location: location,
      geohash: geohash,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      isFlagged: isFlagged ?? this.isFlagged,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
  
  /// Get time ago string (e.g., "5 min ago", "2 hours ago")
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
  
  /// Get distance display string
  String get distanceDisplay {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).round()}m away';
    }
    return '${distanceKm!.toStringAsFixed(1)}km away';
  }
  
  @override
  String toString() => 'CommunityPost($id by $authorName)';
}
