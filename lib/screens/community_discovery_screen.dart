import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:guardian_angel_fyp/screens/community_feed_screen_v2.dart';

import 'community/community_discovery_state.dart';
import 'community/community_discovery_data_provider.dart';

class CommunityDiscoveryScreen extends StatefulWidget {
  const CommunityDiscoveryScreen({super.key});

  @override
  State<CommunityDiscoveryScreen> createState() => _CommunityDiscoveryScreenState();
}

class _CommunityDiscoveryScreenState extends State<CommunityDiscoveryScreen> {
  // Production state management
  CommunityDiscoveryState _state = CommunityDiscoveryState.initial();
  final CommunityDiscoveryDataProvider _dataProvider = CommunityDiscoveryDataProvider.instance;
  
  // Timer for countdown (only runs if event exists)
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final loadedState = await _dataProvider.loadInitialState();
      if (mounted) {
        setState(() {
          _state = loadedState;
        });
        // Start countdown timer only if there's a real upcoming event
        _startCountdownIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = CommunityDiscoveryState(
            isLoading: false,
          );
        });
      }
    }
  }

  void _startCountdownIfNeeded() {
    _countdownTimer?.cancel();
    if (_state.hasUpcomingEvent) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _state.hasUpcomingEvent) {
          setState(() {}); // Trigger rebuild for countdown
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Get current user info
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  String get _userName => FirebaseAuth.instance.currentUser?.displayName ?? 'User';
  String? get _userAvatar => FirebaseAuth.instance.currentUser?.photoURL;

  /// Navigate to community feed - uses V2 with location-based filtering (10km radius)
  void _navigateToFeed(CommunityGroup community) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommunityFeedScreenV2(
          userId: _userId,
          userName: _userName,
          userAvatar: _userAvatar,
        ),
      ),
    );
  }

  /// Navigate to featured community feed
  void _navigateToFeaturedFeed() {
    if (_state.featured == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommunityFeedScreenV2(
          userId: _userId,
          userName: _userName,
          userAvatar: _userAvatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16, bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stories rail - only show if stories exist
                      if (_state.hasStories) _buildStoriesRail(),
                      if (_state.hasStories) const SizedBox(height: 24),
                      // Hero carousel - only show if featured exists
                      if (_state.hasFeatured) _buildHeroCarousel(),
                      if (_state.hasFeatured) const SizedBox(height: 24),
                      // Filter pills always visible (static UI labels)
                      _buildFilterPills(),
                      const SizedBox(height: 24),
                      // Masonry grid - shows communities or empty state
                      _buildMasonryGrid(),
                      const SizedBox(height: 32),
                      _buildFooterNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 12,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7).withOpacity(0.95),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200.withOpacity(0.5))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.chevron_left, color: Colors.blue, size: 28),
                        Text(
                          "Chats",
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Community",
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(CupertinoIcons.person_2_fill, color: Colors.grey.shade500, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoriesRail() {
    // Use real stories from state - no hardcoded data
    final stories = _state.stories;
    if (stories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 95,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final story = stories[index];
          final isNew = story.isNew;
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isNew
                      ? const LinearGradient(
                          colors: [Colors.amber, Colors.orange],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        )
                      : null,
                  color: isNew ? null : Colors.grey.shade300,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: story.imageUrl != null
                        ? Image.network(
                            story.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildStoryPlaceholder(),
                          )
                        : _buildStoryPlaceholder(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                story.name,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
                  color: isNew ? Colors.grey.shade900 : Colors.grey.shade500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoryPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: Icon(CupertinoIcons.person_fill, color: Colors.grey.shade400, size: 24),
    );
  }

  Widget _buildHeroCarousel() {
    // Only render if featured community exists
    final featured = _state.featured;
    if (featured == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "FEATURED TODAY",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _ScaleButton(
            onTap: _navigateToFeaturedFeed,
            child: Container(
              height: 300, // Aspect 4/3 approx
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image (or placeholder)
                    if (featured.imageUrl != null)
                      Image.network(
                        featured.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.amber.shade200),
                      )
                    else
                      Container(color: Colors.amber.shade200),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.shade400.withOpacity(0.8),
                            Colors.orange.shade600.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(CupertinoIcons.sparkles, color: Color(0xFFFEF3C7), size: 14), // yellow-100
                                    const SizedBox(width: 6),
                                    Text(
                                      "Daily Prompt",
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Only show online count if > 0
                              if (featured.onlineCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.person_2_fill, color: Colors.white.withOpacity(0.8), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${featured.onlineCount} Online",
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          // Bottom Content
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                featured.name,
                                style: GoogleFonts.inter(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "\"${featured.prompt}\"",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFFFF7ED), // orange-50
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Only show avatar pile if there are members
                                  if (featured.onlineCount > 0)
                                    _buildAvatarPile(featured.onlineCount)
                                  else
                                    const SizedBox.shrink(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      "Join Discussion",
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildFilterPills() {
    // Use filters from state (static labels are acceptable)
    final filters = _state.availableFilters;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black.withOpacity(0.8) : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
              ),
            ),
            child: Text(
              filters[index],
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMasonryGrid() {
    // Show empty state if no communities and no event
    if (!_state.hasCommunities && !_state.hasUpcomingEvent) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 1. Upcoming Event (Full Width) - only if exists
          if (_state.hasUpcomingEvent) ...[
            _ScaleButton(
              onTap: () {
                // TODO: Navigate to event detail when implemented
                // Event data available: _state.upcomingEvent!
              },
              child: _buildUpcomingEventCard(),
            ),
            const SizedBox(height: 16),
          ],
          
          // 2. Community Cards from state
          if (_state.hasCommunities) _buildCommunityCards(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.person_2, color: Colors.grey.shade400, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              "No Communities Yet",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Communities will appear here when available",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityCards() {
    final communities = _state.communities;
    if (communities.isEmpty) return const SizedBox.shrink();

    // Build cards based on available communities
    // Use masonry layout similar to original
    return Column(
      children: [
        for (int i = 0; i < communities.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < communities.length ? 16 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  child: _ScaleButton(
                    onTap: () => _navigateToFeed(communities[i]),
                    child: _buildCommunityCard(communities[i]),
                  ),
                ),
                const SizedBox(width: 16),
                // Right Column
                Expanded(
                  child: i + 1 < communities.length
                      ? _ScaleButton(
                          onTap: () => _navigateToFeed(communities[i + 1]),
                          child: _buildCommunityCard(communities[i + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommunityCard(CommunityGroup community) {
    final hasImage = community.imageUrl != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or icon
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      community.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: Icon(CupertinoIcons.photo, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ),
                // Live badge only if actually live
                if (community.isLive)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ).animate(onPlay: (c) => c.repeat()).fade(duration: 1000.ms),
                          const SizedBox(width: 6),
                          Text(
                            community.latestActivity ?? "Active",
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.person_2_fill, color: Colors.blue.shade600, size: 20),
            ),
          const SizedBox(height: 12),
          Text(
            community.name,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
              height: 1.1,
            ),
          ),
          if (community.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              community.subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          // Only show avatar pile if members exist
          if (community.memberCount > 0) ...[
            const SizedBox(height: 12),
            _buildAvatarPile(community.memberCount),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingEventCard() {
    // Only render if event exists
    final event = _state.upcomingEvent;
    if (event == null) return const SizedBox.shrink();

    return Container(
      height: 100,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow (Simplified)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ).animate().blur(begin: const Offset(0, 0), end: const Offset(60, 60)),
          ),
          
          Row(
            children: [
              // Date Box - from real event data
              Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.dayAbbreviation,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF87171), // red-400
                      ),
                    ),
                    Text(
                      event.dayNumber,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "UPCOMING EVENT",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF93C5FD), // blue-300
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Real countdown from event start time
                        if (event.countdownDisplay != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Text(
                              event.countdownDisplay!,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        // Host - only if real
                        if (event.host != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "with ${event.host}",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Bell Button
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: const Icon(CupertinoIcons.bell, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Avatar pile - shows placeholder avatars with count
  /// In production, these would be real member avatars from the community
  Widget _buildAvatarPile(int count) {
    // Show placeholder avatars (no fake Unsplash images)
    final displayCount = count > 3 ? 3 : count;
    final remaining = count > 3 ? count - 3 : 0;

    return SizedBox(
      height: 24,
      width: (displayCount + (remaining > 0 ? 1 : 0)) * 14.0 + 10,
      child: Stack(
        children: [
          // Placeholder avatar circles
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(CupertinoIcons.person_fill, color: Colors.grey.shade400, size: 12),
              ),
            ),
          // Count badge
          if (remaining > 0)
            Positioned(
              left: displayCount * 14.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    "+$remaining",
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(0.5),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.shield_fill, size: 12, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              "Verified & Moderated Community",
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleButton({required this.child, this.onTap});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
