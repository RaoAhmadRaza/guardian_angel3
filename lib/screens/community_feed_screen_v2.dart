/// Community Feed Screen V2
/// 
/// Location-based community feed with real Firestore integration.
/// Shows posts from users within 10km radius and provides real-time chat.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../community/community.dart';

class CommunityFeedScreenV2 extends StatefulWidget {
  /// User ID of current user
  final String userId;
  
  /// Display name of current user
  final String userName;
  
  /// Avatar URL (optional)
  final String? userAvatar;

  const CommunityFeedScreenV2({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<CommunityFeedScreenV2> createState() => _CommunityFeedScreenV2State();
}

class _CommunityFeedScreenV2State extends State<CommunityFeedScreenV2> with WidgetsBindingObserver {
  // Providers
  final CommunityFeedProvider _feedProvider = CommunityFeedProvider.instance;
  final CommunityChatProvider _chatProvider = CommunityChatProvider.instance;
  
  // UI State
  String _activeTab = 'feed'; // 'feed' or 'chat'
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isCreatingPost = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    // Initialize feed provider
    await _feedProvider.initialize(
      userName: widget.userName,
      userAvatar: widget.userAvatar,
    );
    
    // Initialize chat provider
    await _chatProvider.initialize(
      userName: widget.userName,
      userAvatar: widget.userAvatar,
    );
    
    // Listen for state changes
    _feedProvider.addListener(_onFeedStateChanged);
    _chatProvider.addListener(_onChatStateChanged);
  }

  void _onFeedStateChanged() {
    if (mounted) setState(() {});
  }

  void _onChatStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _feedProvider.pause();
      _chatProvider.pause();
    } else if (state == AppLifecycleState.resumed) {
      _feedProvider.resume();
      _chatProvider.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _captionController.dispose();
    _chatFocusNode.dispose();
    _feedProvider.removeListener(_onFeedStateChanged);
    _chatProvider.removeListener(_onChatStateChanged);
    super.dispose();
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > 200;
    if (isScrolled != _isScrolled) {
      setState(() => _isScrolled = isScrolled);
    }
  }

  Future<void> _handleLike(CommunityPost post) async {
    await _feedProvider.toggleLike(post.id);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    
    if (photo != null) {
      setState(() => _selectedImage = File(photo.path));
    }
  }

  Future<void> _createPost() async {
    if (_captionController.text.trim().isEmpty && _selectedImage == null) return;
    
    setState(() => _isCreatingPost = true);
    
    final success = await _feedProvider.createPost(
      content: _captionController.text.trim(),
      imageFile: _selectedImage,
    );
    
    setState(() {
      _isCreatingPost = false;
      if (success) {
        _selectedImage = null;
        _captionController.clear();
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    _textController.clear();
    await _chatProvider.sendMessage(text);
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
          child: _ShareMomentModalV2(
            selectedImage: _selectedImage,
            captionController: _captionController,
            isUploading: _isCreatingPost,
            onPickImage: _pickImage,
            onTakePhoto: _takePhoto,
            onClearImage: () => setState(() => _selectedImage = null),
            onShare: _createPost,
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
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = _feedProvider.state;
    final chatState = _chatProvider.state;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(feedState),
              ),
              
              // Tabs Control
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
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
                      borderRadius: BorderRadius.circular(22),
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
                _buildFeedSliver(feedState)
              else
                _buildChatSliver(chatState),
                
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
          
          // Loading Overlay
          if (feedState.isLoading || chatState.isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
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
                            "Nearby Community",
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          Text(
                            "${_feedProvider.state.onlineCount} people nearby",
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
            child: Icon(
              icon,
              color: isScrolled ? Colors.grey.shade900 : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(CommunityFeedState state) {
    final onlineCount = state.onlineCount;
    
    return SizedBox(
      height: 460,
      child: Stack(
        children: [
          // Background gradient (no external image dependency)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade400,
                    Colors.indigo.shade600,
                  ],
                ),
              ),
            ),
          ),
          // Pattern overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    const Color(0xFFF2F2F7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          // Avatar Pile (real nearby users)
          Positioned(
            top: 112,
            right: 24,
            child: _buildNearbyUsersPile(state.nearbyUsers),
          ),

          // Stats
          Positioned(
            bottom: 3,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: CupertinoIcons.person_2_fill,
                        value: '$onlineCount',
                        label: 'Nearby',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      _buildStatItem(
                        icon: CupertinoIcons.doc_text_fill,
                        value: '${state.posts.length}',
                        label: 'Posts',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      _buildStatItem(
                        icon: CupertinoIcons.location_fill,
                        value: '10km',
                        label: 'Radius',
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.1, end: 0, duration: 700.ms, delay: 100.ms),
          ),

          // Title and Info
          Positioned(
            bottom: 76,
            left: 29,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.location_fill, color: Colors.white, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        "LOCATION-BASED",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        )
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Nearby\nCommunity",
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
                const SizedBox(height: 12),
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
                        ).animate(onPlay: (c) => c.repeat()).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(2, 2),
                          duration: 1000.ms,
                        ).fadeOut(),
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
                      onlineCount > 0 ? "$onlineCount people within 10km" : "Scanning for nearby users...",
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
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

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyUsersPile(List<CommunityUser> users) {
    final displayCount = users.length > 3 ? 3 : users.length;
    final remaining = users.length > 3 ? users.length - 3 : 0;
    
    if (users.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        SizedBox(
          width: 36.0 * displayCount + (remaining > 0 ? 36 : 0),
          height: 36,
          child: Stack(
            children: [
              for (int i = 0; i < displayCount; i++)
                Positioned(
                  left: i * 24.0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: users[i].profileImageUrl != null
                          ? Image.network(
                              users[i].profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildUserPlaceholder(),
                            )
                          : _buildUserPlaceholder(),
                    ),
                  ),
                ),
              if (remaining > 0)
                Positioned(
                  left: displayCount * 24.0,
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
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 700.ms).scale();
  }

  Widget _buildUserPlaceholder() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(CupertinoIcons.person_fill, color: Colors.grey.shade500, size: 18),
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

  SliverList _buildFeedSliver(CommunityFeedState state) {
    final posts = state.posts;
    
    if (posts.isEmpty && !state.isLoading) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildEmptyFeedState(),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Feed Items
              ...posts.asMap().entries.map((entry) {
                final index = entry.key;
                final post = entry.value;
                final isLiked = post.likedByMe;

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
                      // Header with author info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade200,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: post.authorAvatarUrl != null
                                    ? Image.network(
                                        post.authorAvatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          CupertinoIcons.person_fill,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                      )
                                    : Icon(
                                        CupertinoIcons.person_fill,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName.isNotEmpty ? post.authorName : 'Anonymous',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        post.timeAgo,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      if (post.distanceKm != null) ...[
                                        Text(
                                          " • ${post.distanceDisplay}",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              CupertinoIcons.ellipsis,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      
                      // Image (if available)
                      if (post.imageUrl != null) ...[
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: AspectRatio(
                                aspectRatio: 4 / 5,
                                child: Image.network(
                                  post.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      CupertinoIcons.photo,
                                      color: Colors.grey.shade400,
                                      size: 48,
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
                                onTap: () => _handleLike(post),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isLiked
                                            ? const Color(0xFFEC4899).withOpacity(0.9)
                                            : Colors.black.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                      ],
                      
                      // Content
                      if (post.content.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            post.content,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      
                      // Likes count (if no image shown)
                      if (post.imageUrl == null && post.likeCount > 0) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _handleLike(post),
                                child: Icon(
                                  isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                  color: isLiked ? const Color(0xFFEC4899) : Colors.grey.shade500,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${post.likeCount} likes',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildEmptyFeedState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.doc_text, color: Colors.blue.shade400, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              "No Posts Yet",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Be the first to share something with your\nnearby community!",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showShareModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "Create Post",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverList _buildChatSliver(CommunityChatState state) {
    final messages = state.messages;
    
    if (messages.isEmpty && !state.isLoading) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildEmptyChatState(),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final msg = messages[index];
          final isMe = _chatProvider.isMyMessage(msg);
          
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
                      color: Colors.grey.shade200,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: msg.senderAvatarUrl != null
                          ? Image.network(
                              msg.senderAvatarUrl!,
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
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? null : Colors.white.withOpacity(0.8),
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
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
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              msg.senderName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        Text(
                          msg.text,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isMe ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(msg.createdAt),
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
        childCount: messages.length,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildEmptyChatState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.chat_bubble_2, color: Colors.blue.shade400, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              "Start Chatting",
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Say hello to others in your area!\nMessages are visible to everyone within 10km.",
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
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
                              colors: [Color(0xFF60A5FA), Color(0xFF6366F1)],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                            shape: BoxShape.circle,
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
                          focusNode: _chatFocusNode,
                          decoration: InputDecoration(
                            hintText: "Message nearby community...",
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
                          onSubmitted: (_) => _sendChatMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendChatMessage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _chatProvider.state.isSending
                                ? Colors.grey.shade200
                                : Colors.blue.shade500,
                            shape: BoxShape.circle,
                          ),
                          child: _chatProvider.state.isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 20),
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

/// Share Moment Modal V2 - with real image picking
class _ShareMomentModalV2 extends StatelessWidget {
  final File? selectedImage;
  final TextEditingController captionController;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final VoidCallback onClearImage;
  final VoidCallback onShare;

  const _ShareMomentModalV2({
    required this.selectedImage,
    required this.captionController,
    required this.isUploading,
    required this.onPickImage,
    required this.onTakePhoto,
    required this.onClearImage,
    required this.onShare,
  });

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
                      const SizedBox(width: 20),
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
                        onTap: isUploading ? null : onPickImage,
                        child: Container(
                          width: double.infinity,
                          height: 280,
                          decoration: BoxDecoration(
                            color: selectedImage != null ? Colors.grey.shade100 : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: selectedImage != null
                                ? Border.all(color: Colors.transparent)
                                : Border.all(color: Colors.grey.shade200, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: selectedImage != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(selectedImage!, fit: BoxFit.cover),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: onClearImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.xmark,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: onTakePhoto,
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.camera,
                                                  color: Colors.blue.shade500,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            GestureDetector(
                                              onTap: onPickImage,
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  CupertinoIcons.photo,
                                                  color: Colors.indigo.shade500,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Capture or choose photo",
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
                        controller: captionController,
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
                        onTap: isUploading ? null : onShare,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (selectedImage != null || captionController.text.isNotEmpty)
                                  ? [Colors.blue.shade500, Colors.indigo.shade600]
                                  : [Colors.grey.shade200, Colors.grey.shade300],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    "Share with Nearby Community",
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: (selectedImage != null || captionController.text.isNotEmpty)
                                          ? Colors.white
                                          : Colors.grey.shade400,
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
