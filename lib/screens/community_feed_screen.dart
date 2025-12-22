import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// Mock Data Models
class ChatSession {
  final String id;
  final String name;
  final String? coverImage;
  final int goalProgress;
  final String? dailyPrompt;
  final List<Message> messages;

  ChatSession({
    required this.id,
    required this.name,
    this.coverImage,
    this.goalProgress = 0,
    this.dailyPrompt,
    this.messages = const [],
  });
}

class Message {
  final String id;
  final String text;
  final String sender; // 'user' or 'other'
  final DateTime timestamp;
  final String? imageUrl;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.imageUrl,
  });
}

class CommunityFeedScreen extends StatefulWidget {
  final ChatSession session;

  const CommunityFeedScreen({super.key, required this.session});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  String _activeTab = 'feed'; // 'feed' or 'chat'
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  final Map<String, bool> _likedPosts = {};
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 200;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  void _handleLike(String msgId) {
    setState(() {
      _likedPosts[msgId] = !(_likedPosts[msgId] ?? false);
    });
  }

  void _showShareModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _ShareMomentModal(
            onShare: (caption, imageUrl) {
              // Handle share logic here (e.g., add to messages)
              setState(() {
                widget.session.messages.add(
                  Message(
                    id: DateTime.now().toString(),
                    text: caption,
                    sender: 'user',
                    timestamp: DateTime.now(),
                    imageUrl: imageUrl,
                  ),
                );
                _activeTab = 'feed';
              });
              // Scroll to top
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  300, // Approximate offset to see feed
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
        );
      },
    );
  }

  String _getPostImage(Message msg, int index) {
    if (msg.imageUrl != null) return msg.imageUrl!;
    final images = [
      "https://images.unsplash.com/photo-1501854140884-074cf2a1a746?auto=format&fit=crop&q=80&w=600",
      "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?auto=format&fit=crop&q=80&w=600",
      "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&q=80&w=600",
      "https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&q=80&w=600"
    ];
    return images[index % images.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Section (as SliverToBoxAdapter since we're managing scroll manually for header)
              SliverToBoxAdapter(
                child: _buildHeroSection(),
              ),
              
              // Tabs Control (Sticky-ish behavior handled by logic, but here just part of flow)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22), // Clip for blur
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Row(
                          children: [
                            Expanded(child: _buildTabButton('feed', 'Social Feed', CupertinoIcons.sparkles)),
                            Expanded(child: _buildTabButton('chat', 'Chat Room', CupertinoIcons.chat_bubble)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              if (_activeTab == 'feed')
                _buildFeedSliver()
              else
                _buildChatSliver(),
                
              // Bottom Padding for Footer
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),

          // Dynamic Header
          _buildDynamicHeader(),

          // Footer Interaction Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 8,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: _isScrolled ? Colors.white.withOpacity(0.9) : Colors.transparent,
          border: _isScrolled ? Border(bottom: BorderSide(color: Colors.grey.shade200.withOpacity(0.5))) : null,
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: _isScrolled ? ImageFilter.blur(sigmaX: 20, sigmaY: 20) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCircleButton(
                      icon: CupertinoIcons.chevron_left,
                      onTap: () => Navigator.of(context).pop(),
                      isScrolled: _isScrolled,
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isScrolled ? 1.0 : 0.0,
                      child: Column(
                        children: [
                          Text(
                            widget.session.name,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          Text(
                            "Community Hub",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildCircleButton(
                      icon: Icons.more_horiz,
                      onTap: () {},
                      isScrolled: _isScrolled,
                    ),
                  ],
                ),
                
                // Segmented Control in Header (Visible on Scroll)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isScrolled ? 40 : 0,
                  margin: EdgeInsets.only(top: _isScrolled ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isScrolled ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                alignment: _activeTab == 'feed' ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  width: (constraints.maxWidth - 8) / 2,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _activeTab = 'feed'),
                                      child: Center(
                                        child: Text(
                                          "Feed",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _activeTab == 'feed' ? Colors.grey.shade900 : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _activeTab = 'chat'),
                                      child: Center(
                                        child: Text(
                                          "Chat Room",
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: _activeTab == 'chat' ? Colors.grey.shade900 : Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap, required bool isScrolled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isScrolled ? Colors.transparent : Colors.black.withOpacity(0.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: isScrolled ? ImageFilter.blur(sigmaX: 0, sigmaY: 0) : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isScrolled ? Colors.transparent : Colors.transparent, // Already handled by decoration color
              child: Icon(
                icon,
                color: isScrolled ? Colors.grey.shade900 : Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return SizedBox(
      height: 420,
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            child: Image.network(
              widget.session.coverImage ?? "https://images.unsplash.com/photo-1511632765486-a01980e01a18?auto=format&fit=crop&q=80&w=1200",
              fit: BoxFit.cover,
            ),
          ),
          // Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    const Color(0xFFF2F2F7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // Avatar Pile
          Positioned(
            top: 112, // top-28 approx
            right: 24,
            child: Row(
              children: [
                SizedBox(
                  width: 36.0 * 3 + 10,
                  height: 36,
                  child: Stack(
                    children: [
                      for (int i = 0; i < 3; i++)
                        Positioned(
                          left: i * 24.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.network(
                                "https://i.pravatar.cc/100?img=${i + 15}",
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 3 * 24.0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Center(
                                child: Text(
                                  "+24",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 700.ms).scale(),
          ),

          // Goal Progress Bar
          Positioned(
            bottom: 128, // bottom-32
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.scope, color: Color(0xFF4ADE80), size: 14), // green-400
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "COMMUNITY GOAL",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "${widget.session.goalProgress}%",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4ADE80),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Stack(
                          children: [
                            FractionallySizedBox(
                              widthFactor: widget.session.goalProgress / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4ADE80), Color(0xFF10B981)],
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF34D399).withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.1, end: 0, duration: 700.ms, delay: 100.ms),
          ),

          // Title and Info
          Positioned(
            bottom: 48, // bottom-12
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.shield_fill, color: Colors.white, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            "VERIFIED GROUP",
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
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.session.name,
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(2, 2), duration: 1000.ms).fadeOut(),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Member activity is high",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? (tab == 'feed' ? Colors.amber.shade600 : Colors.blue.shade500)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.grey.shade900 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _buildFeedSliver() {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Daily Prompt
              Container(
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)], // blue-50 to indigo-50
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.blue.shade100.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Blur Blob
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ).animate().blur(begin: const Offset(0, 0), end: const Offset(40, 40)),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.sparkles, color: Colors.blue.shade500, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "DAILY PROMPT",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\"${widget.session.dailyPrompt ?? "How is your heart feeling today?"}\"",
                            style: GoogleFonts.playfairDisplay( // Using serif font as in reference
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Posted by Community Lead • Today",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 16), // Space for button overlap
                        ],
                      ),
                    ),
                    
                    // Add Yours Button
                    Positioned(
                      bottom: -20,
                      right: 24,
                      child: GestureDetector(
                        onTap: _showShareModal,
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 3,
                                  style: BorderStyle.solid, // Dashed not directly supported on border, simulating with solid for now or custom painter
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(CupertinoIcons.camera_fill, color: Colors.blue.shade500, size: 24),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(CupertinoIcons.add, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Text(
                                "Add Yours",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Feed Items
              ...widget.session.messages.where((m) => m.sender != 'system').toList().asMap().entries.map((entry) {
                final index = entry.key;
                final msg = entry.value;
                final isMe = msg.sender == 'user';
                final isLiked = _likedPosts[msg.id] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Container
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: AspectRatio(
                              aspectRatio: 4 / 5,
                              child: Image.network(
                                _getPostImage(msg, index),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // User Badge
                          Positioned(
                            top: 16,
                            left: 16,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(100),
                                          child: Image.network(
                                            "https://i.pravatar.cc/100?img=${index + 25}",
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isMe ? 'You' : 'Member',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Like Button
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => _handleLike(msg.id),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isLiked ? const Color(0xFFEC4899).withOpacity(0.9) : Colors.black.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      boxShadow: isLiked
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFEC4899).withOpacity(0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.1, end: 0, duration: 500.ms, delay: (index * 100).ms);
              }),
            ],
          ),
        ),
      ]),
    );
  }

  SliverList _buildChatSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final msg = widget.session.messages[index];
          final isMe = msg.sender == 'user';
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Image.network(
                        "https://i.pravatar.cc/100?img=${index + 30}",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? null : Colors.white.withOpacity(0.8),
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)], // blue-500 to indigo-600
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isMe ? 22 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 22),
                      ),
                      border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isMe ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${msg.timestamp.hour}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.blue.shade50 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.1, end: 0, duration: 300.ms);
        },
        childCount: widget.session.messages.length,
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFF2F2F7),
            const Color(0xFFF2F2F7).withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: _activeTab == 'feed'
              ? GestureDetector(
                  onTap: _showShareModal,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF60A5FA), Color(0xFF6366F1)], // blue-400 to indigo-500
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x4D3B82F6), // blue-500 with opacity
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(CupertinoIcons.camera, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Share Moment",
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              "TAP TO CAPTURE",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.add, color: Colors.blue.shade500, size: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CupertinoIcons.add, color: Colors.grey.shade500, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: "Message ${widget.session.name}...",
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey.shade400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey.shade900,
                          ),
                          onSubmitted: (_) {
                            // Handle send
                            _textController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(CupertinoIcons.arrow_up, color: Colors.grey.shade400, size: 20),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ShareMomentModal extends StatefulWidget {
  final Function(String caption, String imageUrl) onShare;

  const _ShareMomentModal({required this.onShare});

  @override
  State<_ShareMomentModal> createState() => _ShareMomentModalState();
}

class _ShareMomentModalState extends State<_ShareMomentModal> {
  String _caption = '';
  String? _selectedImage;
  bool _isUploading = false;

  void _handleSimulateUpload() {
    setState(() => _isUploading = true);
    // Simulate upload
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _selectedImage = "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&q=80&w=800";
          _isUploading = false;
        });
      }
    });
  }

  void _handleShare() {
    if (_selectedImage != null) {
      widget.onShare(_caption, _selectedImage!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.grey, size: 20),
                      ),
                      Text(
                        "Share Moment",
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(width: 20), // Spacer
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Placeholder
                      GestureDetector(
                        onTap: _isUploading ? null : _handleSimulateUpload,
                        child: Container(
                          width: double.infinity,
                          height: 280, // Aspect square approx
                          decoration: BoxDecoration(
                            color: _selectedImage != null ? Colors.grey.shade100 : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: _selectedImage != null
                                ? Border.all(color: Colors.transparent)
                                : Border.all(color: Colors.grey.shade200, width: 2, style: BorderStyle.solid), // Dashed simulation
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _selectedImage != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(_selectedImage!, fit: BoxFit.cover),
                                      Container(
                                        color: Colors.black.withOpacity(0.2),
                                        child: const Center(
                                          child: Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 32),
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: _isUploading
                                              ? const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: CircularProgressIndicator(strokeWidth: 3),
                                                )
                                              : Icon(CupertinoIcons.camera, color: Colors.blue.shade500, size: 32),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Tap to capture or upload",
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Caption Input
                      Text(
                        "CAPTION",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) => setState(() => _caption = value),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Tell your community about this moment...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade300,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Share Button
                      GestureDetector(
                        onTap: _handleShare,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedImage != null
                                  ? [Colors.blue.shade500, Colors.indigo.shade600]
                                  : [Colors.grey.shade200, Colors.grey.shade300],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _selectedImage != null
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.shade500.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              "Share with Community",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _selectedImage != null ? Colors.white : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
