/// Community User Model
/// 
/// Represents a patient user in the location-based community.
/// Stores location data with geohash for efficient geo-queries.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Privacy level for community visibility
enum CommunityVisibility {
  /// Visible to all nearby users
  visible,
  
  /// Hidden from community (location not shared)
  hidden,
  
  /// Only visible to connections/friends
  connectionsOnly,
}

/// Community user with location data
class CommunityUser {
  /// Firebase UID
  final String uid;
  
  /// Display name (from patient profile)
  final String displayName;
  
  /// Profile image URL (optional)
  final String? profileImageUrl;
  
  /// Current latitude
  final double latitude;
  
  /// Current longitude
  final double longitude;
  
  /// GeoPoint for Firestore geo-queries
  final GeoPoint location;
  
  /// Geohash for efficient radius queries
  final String geohash;
  
  /// Last time location was updated
  final DateTime lastLocationUpdate;
  
  /// Whether this is a patient (only patients can participate)
  final bool isPatient;
  
  /// Privacy setting
  final CommunityVisibility visibility;
  
  /// Bio/status message (optional)
  final String? bio;
  
  /// When user joined the community
  final DateTime joinedAt;
  
  /// Whether user is currently online
  final bool isOnline;
  
  const CommunityUser({
    required this.uid,
    required this.displayName,
    this.profileImageUrl,
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.geohash,
    required this.lastLocationUpdate,
    required this.isPatient,
    this.visibility = CommunityVisibility.visible,
    this.bio,
    required this.joinedAt,
    this.isOnline = false,
  });
  
  /// Create from Firestore document
  factory CommunityUser.fromFirestore(Map<String, dynamic> data, String docId) {
    final geoPoint = data['location'] as GeoPoint?;
    
    return CommunityUser(
      uid: docId,
      displayName: data['displayName'] as String? ?? 'Anonymous',
      profileImageUrl: data['profileImageUrl'] as String?,
      latitude: data['latitude'] as double? ?? geoPoint?.latitude ?? 0.0,
      longitude: data['longitude'] as double? ?? geoPoint?.longitude ?? 0.0,
      location: geoPoint ?? const GeoPoint(0, 0),
      geohash: data['geohash'] as String? ?? '',
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate() 
          ?? DateTime.now(),
      isPatient: data['isPatient'] as bool? ?? true,
      visibility: CommunityVisibility.values.firstWhere(
        (v) => v.name == (data['visibility'] as String?),
        orElse: () => CommunityVisibility.visible,
      ),
      bio: data['bio'] as String?,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'geohash': geohash,
      'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate),
      'isPatient': isPatient,
      'visibility': visibility.name,
      'bio': bio,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isOnline': isOnline,
    };
  }
  
  /// Create a copy with updated fields
  CommunityUser copyWith({
    String? displayName,
    String? profileImageUrl,
    double? latitude,
    double? longitude,
    GeoPoint? location,
    String? geohash,
    DateTime? lastLocationUpdate,
    bool? isPatient,
    CommunityVisibility? visibility,
    String? bio,
    DateTime? joinedAt,
    bool? isOnline,
  }) {
    return CommunityUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
      isPatient: isPatient ?? this.isPatient,
      visibility: visibility ?? this.visibility,
      bio: bio ?? this.bio,
      joinedAt: joinedAt ?? this.joinedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }
  
  /// Check if location is recent (within last 30 minutes)
  bool get hasRecentLocation {
    return DateTime.now().difference(lastLocationUpdate).inMinutes <= 30;
  }
  
  /// Check if user is visible in community
  bool get isVisible => visibility == CommunityVisibility.visible;
  
  @override
  String toString() => 'CommunityUser($displayName, $geohash)';
}
