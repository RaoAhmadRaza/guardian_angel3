/// Community Discovery Screen V2
/// 
/// Location-based community discovery with real Firestore integration.
/// Shows nearby users and allows joining the community feed.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../community/community.dart';
import 'community_feed_screen_v2.dart';

class CommunityDiscoveryScreenV2 extends StatefulWidget {
  /// Current user ID
  final String userId;
  
  /// Current user display name
  final String userName;
  
  /// Current user avatar URL (optional)
  final String? userAvatar;

  const CommunityDiscoveryScreenV2({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<CommunityDiscoveryScreenV2> createState() => _CommunityDiscoveryScreenV2State();
}

class _CommunityDiscoveryScreenV2State extends State<CommunityDiscoveryScreenV2> with WidgetsBindingObserver {
  // Services
  final CommunityLocationService _locationService = CommunityLocationService.instance;
  final NearbyUsersService _nearbyUsersService = NearbyUsersService.instance;
  
  // State
  bool _isLoading = true;
  String? _error;
  List<CommunityUser> _nearbyUsers = [];
  int _onlineCount = 0;
  bool _isVisible = true;
  
  // Subscriptions
  StreamSubscription<List<CommunityUser>>? _usersSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Initialize nearby users service
      await _nearbyUsersService.initialize(
        currentUserId: widget.userId,
        currentUserName: widget.userName,
        currentUserAvatar: widget.userAvatar,
      );
      
      // Check visibility setting
      _isVisible = await _locationService.isVisible;
      
      // Subscribe to nearby users
      _usersSubscription = _nearbyUsersService.usersStream.listen(
        (users) {
          if (mounted) {
            setState(() {
              _nearbyUsers = users;
              _onlineCount = users.length;
            });
          }
        },
        onError: (e) {
          debugPrint('[CommunityDiscoveryV2] Users stream error: $e');
        },
      );
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not access your location. Please enable location services.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _nearbyUsersService.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usersSubscription?.cancel();
    super.dispose();
  }

  void _navigateToFeed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommunityFeedScreenV2(
          userId: widget.userId,
          userName: widget.userName,
          userAvatar: widget.userAvatar,
        ),
      ),
    );
  }

  Future<void> _toggleVisibility() async {
    final newValue = !_isVisible;
    await _locationService.setVisibility(newValue);
    setState(() => _isVisible = newValue);
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 16, bottom: 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hero Section
                                _buildHeroSection(),
                                const SizedBox(height: 24),
                                // Nearby Users Section
                                _buildNearbyUsersSection(),
                                const SizedBox(height: 24),
                                // Privacy Settings
                                _buildPrivacySettings(),
                                const SizedBox(height: 24),
                                // Features Section
                                _buildFeaturesSection(),
                                const SizedBox(height: 32),
                                _buildFooterNote(),
                              ],
                            ),
                          ),
              ),
            ],
          ),
          
          // Join Button FAB
          if (!_isLoading && _error == null)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: _buildJoinButton(),
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
                          "Back",
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
                    "Nearby",
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
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
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$_onlineCount Online",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _ScaleButton(
        onTap: _navigateToFeed,
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade400,
                Colors.indigo.shade600,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row with badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.location_fill, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "10km Radius",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_onlineCount > 0)
                          _buildAvatarPile(),
                      ],
                    ),
                    
                    // Bottom content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(CupertinoIcons.person_2_fill, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Nearby\nCommunity",
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _onlineCount > 0
                              ? "Connect with $_onlineCount people in your area"
                              : "Be the first to join in your area",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            "Join Community",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildAvatarPile() {
    final displayCount = _nearbyUsers.length > 3 ? 3 : _nearbyUsers.length;
    final remaining = _nearbyUsers.length > 3 ? _nearbyUsers.length - 3 : 0;
    
    if (_nearbyUsers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: _nearbyUsers[i].profileImageUrl != null
                      ? Image.network(
                          _nearbyUsers[i].profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            CupertinoIcons.person_fill,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                        )
                      : Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayCount * 20.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Center(
                  child: Text(
                    "+$remaining",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyUsersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PEOPLE NEARBY",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_nearbyUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.person_2, color: Colors.grey.shade400, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "No one nearby yet",
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          "Invite others to join the community",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: _nearbyUsers.take(5).map((user) {
                  final distance = _nearbyUsersService.getDistanceDisplay(user);
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: user != _nearbyUsers.take(5).last ? 1 : 0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: user.profileImageUrl != null
                                ? Image.network(
                                    user.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      CupertinoIcons.person_fill,
                                      color: Colors.grey.shade400,
                                      size: 22,
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.person_fill,
                                    color: Colors.grey.shade400,
                                    size: 22,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                distance,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Online",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isVisible ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isVisible ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                color: _isVisible ? Colors.green : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Visibility",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  Text(
                    _isVisible ? "Others can see you nearby" : "You're hidden from others",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: _isVisible,
              onChanged: (_) => _toggleVisibility(),
              activeTrackColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "FEATURES",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: CupertinoIcons.doc_text_fill,
                  title: "Posts",
                  subtitle: "Share moments",
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  title: "Chat",
                  subtitle: "Real-time messaging",
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: CupertinoIcons.location_fill,
                  title: "Location",
                  subtitle: "10km radius",
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeatureCard(
                  icon: CupertinoIcons.shield_fill,
                  title: "Privacy",
                  subtitle: "Patients only",
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return GestureDetector(
      onTap: _navigateToFeed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade500, Colors.indigo.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.person_2_fill, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              "Join Nearby Community",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms, delay: 300.ms);
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.location_slash_fill, color: Colors.red.shade400, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            "Location Required",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? "Please enable location services to join the community.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _initialize,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade500,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                "Try Again",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              "Patient-only community • Secure & Private",
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
