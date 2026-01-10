/// Community Feed Provider
/// 
/// State management for the community feed.
/// Manages posts, location updates, and user interactions.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/services.dart';

/// State for the community feed
class CommunityFeedState {
  /// List of nearby posts
  final List<CommunityPost> posts;
  
  /// List of nearby users
  final List<CommunityUser> nearbyUsers;
  
  /// Loading state
  final bool isLoading;
  
  /// Error message if any
  final String? error;
  
  /// Whether location is available
  final bool hasLocation;
  
  /// Current user's profile
  final CommunityUser? currentUser;
  
  /// Online users count
  final int onlineCount;
  
  const CommunityFeedState({
    this.posts = const [],
    this.nearbyUsers = const [],
    this.isLoading = true,
    this.error,
    this.hasLocation = false,
    this.currentUser,
    this.onlineCount = 0,
  });
  
  /// Initial loading state
  factory CommunityFeedState.initial() {
    return const CommunityFeedState(isLoading: true);
  }
  
  /// Error state
  factory CommunityFeedState.error(String message) {
    return CommunityFeedState(
      isLoading: false,
      error: message,
    );
  }
  
  /// Copy with new values
  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    List<CommunityUser>? nearbyUsers,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? hasLocation,
    CommunityUser? currentUser,
    int? onlineCount,
  }) {
    return CommunityFeedState(
      posts: posts ?? this.posts,
      nearbyUsers: nearbyUsers ?? this.nearbyUsers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasLocation: hasLocation ?? this.hasLocation,
      currentUser: currentUser ?? this.currentUser,
      onlineCount: onlineCount ?? this.onlineCount,
    );
  }
}

/// Provider for community feed state
class CommunityFeedProvider extends ChangeNotifier {
  CommunityFeedProvider._();
  
  static final CommunityFeedProvider _instance = CommunityFeedProvider._();
  static CommunityFeedProvider get instance => _instance;
  
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  final CommunityPostService _postService = CommunityPostService.instance;
  final NearbyUsersService _usersService = NearbyUsersService.instance;
  
  /// Current state
  CommunityFeedState _state = CommunityFeedState.initial();
  CommunityFeedState get state => _state;
  
  /// Stream subscriptions
  StreamSubscription<List<CommunityPost>>? _postsSubscription;
  StreamSubscription<List<CommunityUser>>? _usersSubscription;
  
  /// User info for posting
  String _userName = '';
  String? _userAvatar;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Initialize the provider
  Future<bool> initialize({
    required String userName,
    String? userAvatar,
  }) async {
    debugPrint('[CommunityFeedProvider] Initializing...');
    
    _userName = userName;
    _userAvatar = userAvatar;
    
    _state = CommunityFeedState.initial();
    notifyListeners();
    
    // Check location permission
    final hasPermission = await _locationService.checkLocationPermission();
    if (!hasPermission) {
      _state = CommunityFeedState.error('Location permission required for community features');
      notifyListeners();
      return false;
    }
    
    // Update location in Firestore
    final locationUpdated = await _locationService.updateLocationInFirestore(
      displayName: userName,
      profileImageUrl: userAvatar,
      forceUpdate: true,
    );
    
    if (!locationUpdated) {
      _state = CommunityFeedState.error('Could not get your location');
      notifyListeners();
      return false;
    }
    
    // Initialize post service
    final postInitialized = await _postService.initialize();
    if (!postInitialized) {
      _state = CommunityFeedState.error('Could not load posts');
      notifyListeners();
      return false;
    }
    
    // Initialize users service
    await _usersService.initialize();
    
    // Get current user profile
    final currentUser = await _locationService.getCurrentUserProfile();
    
    // Start listening to streams
    _subscribeToStreams();
    
    _state = _state.copyWith(
      isLoading: false,
      hasLocation: true,
      currentUser: currentUser,
      clearError: true,
    );
    notifyListeners();
    
    debugPrint('[CommunityFeedProvider] Initialized');
    return true;
  }
  
  /// Subscribe to real-time streams
  void _subscribeToStreams() {
    // Posts stream
    _postsSubscription?.cancel();
    _postsSubscription = _postService.postsStream.listen(
      (posts) {
        _state = _state.copyWith(posts: posts);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[CommunityFeedProvider] Posts stream error: $e');
      },
    );
    
    // Users stream
    _usersSubscription?.cancel();
    _usersSubscription = _usersService.usersStream.listen(
      (users) {
        _state = _state.copyWith(
          nearbyUsers: users,
          onlineCount: users.where((u) => u.isOnline).length,
        );
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[CommunityFeedProvider] Users stream error: $e');
      },
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // POST ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Create a new post
  Future<bool> createPost({
    required String content,
    File? imageFile,
  }) async {
    final post = await _postService.createPost(
      content: content,
      imageFile: imageFile,
      authorName: _userName,
      authorAvatar: _userAvatar,
    );
    
    return post != null;
  }
  
  /// Toggle like on a post
  Future<bool> toggleLike(String postId) async {
    return _postService.toggleLike(postId);
  }
  
  /// Check if post is liked by current user
  bool isPostLiked(String postId) {
    return _postService.isLiked(postId);
  }
  
  /// Delete a post
  Future<bool> deletePost(String postId) async {
    return _postService.deletePost(postId);
  }
  
  /// Report a post
  Future<bool> reportPost(String postId) async {
    return _postService.reportPost(postId);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Refresh location
  Future<void> refreshLocation() async {
    await _postService.refreshLocation();
    await _usersService.refreshLocation();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get distance display for a user
  String getDistanceToUser(CommunityUser user) {
    return _usersService.getDistanceDisplay(user);
  }
  
  /// Get nearby users sorted by distance
  List<CommunityUser> get nearbyUsersSorted {
    return _usersService.getUsersSortedByDistance();
  }
  
  /// Get online users
  List<CommunityUser> get onlineUsers {
    return _usersService.getOnlineUsers();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Pause when screen not visible
  void pause() {
    _postService.pause();
    _usersService.pause();
    _locationService.setOffline();
  }
  
  /// Resume when screen visible
  Future<void> resume() async {
    _postService.resume();
    _usersService.resume();
    await _locationService.updateLocationInFirestore(
      displayName: _userName,
      profileImageUrl: _userAvatar,
    );
  }
  
  @override
  void dispose() {
    _postsSubscription?.cancel();
    _usersSubscription?.cancel();
    _locationService.setOffline();
    super.dispose();
  }
}
