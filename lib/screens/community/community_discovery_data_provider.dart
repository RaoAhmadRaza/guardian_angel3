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
  /// Returns empty state for first-time users when demo mode is off
  Future<CommunityDiscoveryState> loadInitialState() async {
    await initialize();
    
    // Check if demo mode is enabled
    await DemoModeService.instance.initialize();
    if (DemoModeService.instance.isEnabled) {
      return CommunityDemoData.state;
    }
    
    // Load real data from Hive
    // Load stories
    final storiesRaw = _box?.get(_storiesKey) as List<dynamic>?;
    final stories = storiesRaw
        ?.map((e) => StoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [];
    
    // Load featured community
    final featuredRaw = _box?.get(_featuredKey) as Map<dynamic, dynamic>?;
    final featured = featuredRaw != null
        ? FeaturedCommunity.fromMap(Map<String, dynamic>.from(featuredRaw))
        : null;
    
    // Load communities
    final communitiesRaw = _box?.get(_communitiesKey) as List<dynamic>?;
    final communities = communitiesRaw
        ?.map((e) => CommunityGroup.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList() ?? [];
    
    // Load upcoming event
    final eventRaw = _box?.get(_eventKey) as Map<dynamic, dynamic>?;
    final upcomingEvent = eventRaw != null
        ? CommunityEvent.fromMap(Map<String, dynamic>.from(eventRaw))
        : null;
    
    return CommunityDiscoveryState(
      stories: stories,
      featured: featured,
      communities: communities,
      upcomingEvent: upcomingEvent,
      isLoading: false,
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
