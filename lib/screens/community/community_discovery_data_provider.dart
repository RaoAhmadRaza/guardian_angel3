/// Community Discovery Data Provider
/// 
/// Loads community data from local storage ONLY.
/// Supports Demo Mode for showcasing UI with sample data.
/// Returns empty state for first-time users when demo mode is off.
library;

import 'package:hive_flutter/hive_flutter.dart';
import '../../services/demo_mode_service.dart';
import '../../services/demo_data.dart';
import 'community_discovery_state.dart';

/// Data provider for Community Discovery screen
/// 
/// Responsibilities:
/// - Load real community data from local storage
/// - Return demo data when Demo Mode is enabled
/// - Return empty/null for missing data when demo mode is off
class CommunityDiscoveryDataProvider {
  static CommunityDiscoveryDataProvider? _instance;
  
  /// Singleton instance
  static CommunityDiscoveryDataProvider get instance {
    _instance ??= CommunityDiscoveryDataProvider._();
    return _instance!;
  }
  
  CommunityDiscoveryDataProvider._();

  /// Hive box name for community data
  static const String _boxName = 'community_discovery_data';
  
  /// Keys for stored values
  static const String _storiesKey = 'stories';
  static const String _featuredKey = 'featured';
  static const String _communitiesKey = 'communities';
  static const String _eventKey = 'upcoming_event';

  Box<dynamic>? _box;

  /// Initialize the data provider (open Hive box)
  Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  /// Load initial state from local storage
  /// Returns demo data if Demo Mode is enabled
  /// Returns suggested communities for first-time users when demo mode is off
  Future<CommunityDiscoveryState> loadInitialState() async {
    await initialize();
    
    // Check if demo mode is enabled
    await DemoModeService.instance.initialize();
    if (DemoModeService.instance.isEnabled) {
      return CommunityDemoData.state;
    }
    
    // Load real data from Hive
    // Load stories (from local cache if any)
    final storiesRaw = _box?.get(_storiesKey) as List<dynamic>?;
    final stories = storiesRaw
        ?.map((e) => StoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [];
    
    // Load upcoming event (from local cache if any)
    final eventRaw = _box?.get(_eventKey) as Map<dynamic, dynamic>?;
    final upcomingEvent = eventRaw != null
        ? CommunityEvent.fromMap(Map<String, dynamic>.from(eventRaw))
        : null;
    
    // Always show the 4 default communities for all users
    // These are global communities - content is filtered by 10km radius
    final communities = _getDefaultCommunities();
    
    // Also provide a default featured community
    final featured = _getDefaultFeaturedCommunity();
    
    return CommunityDiscoveryState(
      stories: stories,
      featured: featured,
      communities: communities,
      upcomingEvent: upcomingEvent,
      isLoading: false,
    );
  }

  /// The 4 default global communities for ALL users
  /// Content inside each community is filtered by 10km radius
  List<CommunityGroup> _getDefaultCommunities() {
    return [
      CommunityGroup(
        id: 'community-morning-walks',
        name: 'Morning Walks',
        subtitle: 'Health & Fitness',
        memberCount: 324,
        imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=800&q=80',
        isLive: true,
        latestActivity: 'Active now',
      ),
      CommunityGroup(
        id: 'community-book-club',
        name: 'Book Club',
        subtitle: 'Reading & Learning',
        memberCount: 89,
        imageUrl: 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=800&q=80',
        isLive: false,
        latestActivity: 'Quiet',
      ),
      CommunityGroup(
        id: 'community-prayer-circle',
        name: 'Prayer Circle',
        subtitle: 'Faith & Spirituality',
        memberCount: 156,
        imageUrl: 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&w=800&q=80',
        isLive: true,
        latestActivity: '7:00 AM Daily',
      ),
      CommunityGroup(
        id: 'community-heart-health',
        name: 'Heart Health',
        subtitle: 'Wellness & Support',
        memberCount: 512,
        imageUrl: 'https://images.unsplash.com/photo-1559757175-5700dde675bc?auto=format&fit=crop&w=800&q=80',
        isLive: true,
        latestActivity: 'Active now',
      ),
    ];
  }

  /// Default featured community
  FeaturedCommunity _getDefaultFeaturedCommunity() {
    return FeaturedCommunity(
      id: 'featured-heart-warriors',
      name: 'Heart Health Warriors',
      prompt: 'Share your heart-healthy tip of the day! 💪❤️',
      onlineCount: 47,
      imageUrl: 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&w=800&q=80',
    );
  }

  /// Save stories to local storage
  Future<void> saveStories(List<StoryItem> stories) async {
    await initialize();
    await _box?.put(_storiesKey, stories.map((s) => s.toMap()).toList());
  }

  /// Save featured community to local storage
  Future<void> saveFeatured(FeaturedCommunity featured) async {
    await initialize();
    await _box?.put(_featuredKey, featured.toMap());
  }

  /// Clear featured community
  Future<void> clearFeatured() async {
    await initialize();
    await _box?.delete(_featuredKey);
  }

  /// Save communities to local storage
  Future<void> saveCommunities(List<CommunityGroup> communities) async {
    await initialize();
    await _box?.put(_communitiesKey, communities.map((c) => c.toMap()).toList());
  }

  /// Save upcoming event to local storage
  Future<void> saveUpcomingEvent(CommunityEvent event) async {
    await initialize();
    await _box?.put(_eventKey, event.toMap());
  }

  /// Clear upcoming event
  Future<void> clearUpcomingEvent() async {
    await initialize();
    await _box?.delete(_eventKey);
  }

  /// Check if user has any community data
  Future<bool> hasAnyData() async {
    await initialize();
    return _box?.get(_storiesKey) != null ||
           _box?.get(_featuredKey) != null ||
           _box?.get(_communitiesKey) != null ||
           _box?.get(_eventKey) != null;
  }

  /// Mark a story as viewed (no longer new)
  Future<void> markStoryViewed(String storyId) async {
    await initialize();
    final storiesRaw = _box?.get(_storiesKey) as List<dynamic>?;
    if (storiesRaw == null) return;
    
    final stories = storiesRaw
        .map((e) => StoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    
    final updatedStories = stories.map((s) {
      if (s.id == storyId) {
        return StoryItem(
          id: s.id,
          name: s.name,
          imageUrl: s.imageUrl,
          isNew: false,
        );
      }
      return s;
    }).toList();
    
    await saveStories(updatedStories);
  }
}
