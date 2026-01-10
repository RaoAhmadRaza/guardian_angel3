/// Nearby Users Service
/// 
/// Service for finding and managing nearby community users.
/// Provides real-time updates of users within 10km radius.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import '../repositories/community_firestore_repository.dart';
import 'community_location_service.dart';

/// Service for finding nearby users
class NearbyUsersService {
  NearbyUsersService._();
  
  static final NearbyUsersService _instance = NearbyUsersService._();
  static NearbyUsersService get instance => _instance;
  
  final CommunityFirestoreRepository _repository = CommunityFirestoreRepository.instance;
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  
  /// Current location cache
  Position? _currentPosition;
  
  /// Users stream subscription
  StreamSubscription<List<CommunityUser>>? _usersSubscription;
  
  /// Users stream controller
  final StreamController<List<CommunityUser>> _usersController = 
      StreamController<List<CommunityUser>>.broadcast();
  
  /// Stream of nearby users
  Stream<List<CommunityUser>> get usersStream => _usersController.stream;
  
  /// Cached users
  List<CommunityUser> _cachedUsers = [];
  List<CommunityUser> get cachedUsers => _cachedUsers;
  
  /// Online users count
  int get onlineCount => _cachedUsers.where((u) => u.isOnline).length;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// User info for location update
  String _userName = '';
  String? _userAvatar;
  
  /// Initialize and start finding nearby users
  /// Accepts optional user info for profile visibility
  Future<bool> initialize({
    String? currentUserId,
    String? currentUserName,
    String? currentUserAvatar,
  }) async {
    debugPrint('[NearbyUsersService] Initializing...');
    
    if (currentUserName != null) {
      _userName = currentUserName;
      _userAvatar = currentUserAvatar;
      
      // Update location in Firestore with user info
      await _locationService.updateLocationInFirestore(
        displayName: _userName,
        profileImageUrl: _userAvatar,
        forceUpdate: true,
      );
    }
    
    // Get current location
    _currentPosition = await _locationService.getCurrentLocation();
    if (_currentPosition == null) {
      debugPrint('[NearbyUsersService] Cannot initialize - no location');
      return false;
    }
    
    // Start listening for nearby users
    _startUsersStream();
    
    debugPrint('[NearbyUsersService] Initialized');
    return true;
  }
  
  /// Refresh users (reloads location and restarts stream)
  Future<void> refresh() async {
    await refreshLocation();
  }
  
  /// Start streaming nearby users from Firestore
  void _startUsersStream() {
    if (_currentPosition == null) return;
    
    _usersSubscription?.cancel();
    _usersSubscription = _repository.streamUsersNearby(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: 10.0,
    ).listen(
      (users) {
        _cachedUsers = users;
        _usersController.add(users);
        debugPrint('[NearbyUsersService] Found ${users.length} nearby users (${onlineCount} online)');
      },
      onError: (e) {
        debugPrint('[NearbyUsersService] Stream error: $e');
      },
    );
  }
  
  /// Refresh location and restart stream
  Future<void> refreshLocation() async {
    _currentPosition = await _locationService.getCurrentLocation(forceRefresh: true);
    if (_currentPosition != null) {
      _startUsersStream();
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get nearby users (one-time, not streaming)
  Future<List<CommunityUser>> getNearbyUsers() async {
    if (_currentPosition == null) {
      _currentPosition = await _locationService.getCurrentLocation();
    }
    
    if (_currentPosition == null) return [];
    
    return _repository.getUsersNearby(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusKm: 10.0,
    );
  }
  
  /// Get a specific user by UID
  Future<CommunityUser?> getUser(String uid) async {
    // Check cache first
    final cached = _cachedUsers.where((u) => u.uid == uid).firstOrNull;
    if (cached != null) return cached;
    
    return _repository.getUser(uid);
  }
  
  /// Get distance to a specific user
  double? getDistanceToUser(CommunityUser user) {
    if (_currentPosition == null) return null;
    
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      user.latitude,
      user.longitude,
    );
  }
  
  /// Get formatted distance string
  String getDistanceDisplay(CommunityUser user) {
    final distance = getDistanceToUser(user);
    if (distance == null) return '';
    
    if (distance < 1) {
      return '${(distance * 1000).round()}m away';
    }
    return '${distance.toStringAsFixed(1)}km away';
  }
  
  /// Get users sorted by distance
  List<CommunityUser> getUsersSortedByDistance() {
    if (_currentPosition == null) return _cachedUsers;
    
    final sorted = List<CommunityUser>.from(_cachedUsers);
    sorted.sort((a, b) {
      final distA = _locationService.calculateDistance(
        _currentPosition!.latitude, _currentPosition!.longitude,
        a.latitude, a.longitude,
      );
      final distB = _locationService.calculateDistance(
        _currentPosition!.latitude, _currentPosition!.longitude,
        b.latitude, b.longitude,
      );
      return distA.compareTo(distB);
    });
    
    return sorted;
  }
  
  /// Get online users only
  List<CommunityUser> getOnlineUsers() {
    return _cachedUsers.where((u) => u.isOnline).toList();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Dispose resources
  void dispose() {
    _usersSubscription?.cancel();
    _usersController.close();
  }
  
  /// Pause streaming
  void pause() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
  }
  
  /// Resume streaming
  void resume() {
    if (_currentPosition != null && _usersSubscription == null) {
      _startUsersStream();
    }
  }
}
