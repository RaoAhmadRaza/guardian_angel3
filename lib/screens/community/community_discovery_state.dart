/// Community Discovery Screen State Model
/// 
/// Production-ready state for the community discovery hub.
/// All lists can be empty and nullable fields support first-time users.
library;

/// Story item displayed in the stories rail
class StoryItem {
  final String id;
  final String name;
  final String? imageUrl;
  final bool isNew;

  const StoryItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isNew = false,
  });

  /// Create from local storage map
  factory StoryItem.fromMap(Map<String, dynamic> map) {
    return StoryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      isNew: map['isNew'] as bool? ?? false,
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'isNew': isNew,
    };
  }
}

/// Featured community displayed in hero card
class FeaturedCommunity {
  final String id;
  final String name;
  final String prompt;
  final String? imageUrl;
  final int onlineCount;

  const FeaturedCommunity({
    required this.id,
    required this.name,
    required this.prompt,
    this.imageUrl,
    this.onlineCount = 0,
  });

  /// Create from local storage map
  factory FeaturedCommunity.fromMap(Map<String, dynamic> map) {
    return FeaturedCommunity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      onlineCount: map['onlineCount'] as int? ?? 0,
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'onlineCount': onlineCount,
    };
  }
}

/// Community group card data
class CommunityGroup {
  final String id;
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final bool isLive;
  final int memberCount;
  final String? latestActivity; // e.g., "Sarah posted" - only if real

  const CommunityGroup({
    required this.id,
    required this.name,
    this.subtitle,
    this.imageUrl,
    this.isLive = false,
    this.memberCount = 0,
    this.latestActivity,
  });

  /// Create from local storage map
  factory CommunityGroup.fromMap(Map<String, dynamic> map) {
    return CommunityGroup(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      imageUrl: map['imageUrl'] as String?,
      isLive: map['isLive'] as bool? ?? false,
      memberCount: map['memberCount'] as int? ?? 0,
      latestActivity: map['latestActivity'] as String?,
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'isLive': isLive,
      'memberCount': memberCount,
      'latestActivity': latestActivity,
    };
  }
}

/// Upcoming community event
class CommunityEvent {
  final String id;
  final DateTime startTime;
  final String title;
  final String? host;
  final String? imageUrl;

  const CommunityEvent({
    required this.id,
    required this.startTime,
    required this.title,
    this.host,
    this.imageUrl,
  });

  /// Create from local storage map
  factory CommunityEvent.fromMap(Map<String, dynamic> map) {
    return CommunityEvent(
      id: map['id'] as String? ?? '',
      startTime: map['startTime'] != null 
          ? DateTime.parse(map['startTime'] as String)
          : DateTime.now(),
      title: map['title'] as String? ?? '',
      host: map['host'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  /// Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'title': title,
      'host': host,
      'imageUrl': imageUrl,
    };
  }

  /// Calculate time remaining until event starts
  /// Returns null if event has passed
  Duration? get timeRemaining {
    final now = DateTime.now();
    if (startTime.isBefore(now)) return null;
    return startTime.difference(now);
  }

  /// Format countdown display
  String? get countdownDisplay {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours h : $minutes m : $seconds s';
  }

  /// Get day abbreviation (e.g., "SUN")
  String get dayAbbreviation {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[startTime.weekday - 1];
  }

  /// Get day number
  String get dayNumber => startTime.day.toString();
}

/// Main state class for Community Discovery screen
class CommunityDiscoveryState {
  /// Stories in the horizontal rail
  final List<StoryItem> stories;
  
  /// Featured community (null if none)
  final FeaturedCommunity? featured;
  
  /// All community groups
  final List<CommunityGroup> communities;
  
  /// Upcoming event (null if none)
  final CommunityEvent? upcomingEvent;
  
  /// Available filter options
  final List<String> availableFilters;
  
  /// Loading state
  final bool isLoading;

  const CommunityDiscoveryState({
    this.stories = const [],
    this.featured,
    this.communities = const [],
    this.upcomingEvent,
    this.availableFilters = const ['All', 'Active Now', 'Quiet', 'Reading', 'Outdoors', 'Wellness'],
    this.isLoading = false,
  });

  /// Initial empty state for first-time users
  factory CommunityDiscoveryState.initial() {
    return const CommunityDiscoveryState(
      stories: [],
      featured: null,
      communities: [],
      upcomingEvent: null,
      availableFilters: ['All', 'Active Now', 'Quiet', 'Reading', 'Outdoors', 'Wellness'],
      isLoading: true,
    );
  }

  /// Create a copy with updated fields
  CommunityDiscoveryState copyWith({
    List<StoryItem>? stories,
    FeaturedCommunity? featured,
    bool clearFeatured = false,
    List<CommunityGroup>? communities,
    CommunityEvent? upcomingEvent,
    bool clearEvent = false,
    List<String>? availableFilters,
    bool? isLoading,
  }) {
    return CommunityDiscoveryState(
      stories: stories ?? this.stories,
      featured: clearFeatured ? null : (featured ?? this.featured),
      communities: communities ?? this.communities,
      upcomingEvent: clearEvent ? null : (upcomingEvent ?? this.upcomingEvent),
      availableFilters: availableFilters ?? this.availableFilters,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // === Computed Properties ===

  /// Whether stories rail should be shown
  bool get hasStories => stories.isNotEmpty;

  /// Whether featured section should be shown
  bool get hasFeatured => featured != null;

  /// Whether there are any communities to display
  bool get hasCommunities => communities.isNotEmpty;

  /// Whether upcoming event should be shown
  bool get hasUpcomingEvent => upcomingEvent != null && upcomingEvent!.timeRemaining != null;

  /// Whether the screen is completely empty (first-time user)
  bool get isEmpty => !hasStories && !hasFeatured && !hasCommunities && !hasUpcomingEvent;
}
