import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class ChatScreenNew extends StatefulWidget {
  const ChatScreenNew({super.key});

  @override
  State<ChatScreenNew> createState() => _ChatScreenNewState();
}

class _ChatScreenNewState extends State<ChatScreenNew>
    with TickerProviderStateMixin {
  late AnimationController _aiCardController;
  late AnimationController _caregiverCardController;
  late Animation<double> _aiCardScale;
  late Animation<double> _caregiverCardScale;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers for card interactions
    _aiCardController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _caregiverCardController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Initialize scale animations
    _aiCardScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _aiCardController,
      curve: Curves.easeOut,
    ));

    _caregiverCardScale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _caregiverCardController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _aiCardController.dispose();
    _caregiverCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top spacing for premium feel
              const SizedBox(height: 24),

              // Header Section
              _buildHeader(isDarkMode),

              // Main content with cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      // Chat with AI Card
                      _buildChatCard(
                        isDarkMode: isDarkMode,
                        title: 'Chat with AI',
                        subtitle: 'Get instant smart assistance',
                        icon: CupertinoIcons.chat_bubble_2_fill,
                        scale: _aiCardScale,
                        onTapDown: (_) {
                          HapticFeedback.lightImpact();
                          _aiCardController.forward();
                        },
                        onTapUp: (_) {
                          _aiCardController.reverse();
                        },
                        onTapCancel: () {
                          _aiCardController.reverse();
                        },
                        onTap: () {
                          // Handle AI Chat navigation
                          print('Navigate to AI Chat');
                        },
                        imageAsset:
                            'images/ai_assistant.png', // Placeholder for AI character
                      ),

                      const SizedBox(height: 24),

                      // Chat with Caregiver Card
                      _buildChatCard(
                        isDarkMode: isDarkMode,
                        title: 'Chat with Caregiver',
                        subtitle: 'Stay connected with your support',
                        icon: CupertinoIcons.heart_fill,
                        scale: _caregiverCardScale,
                        onTapDown: (_) {
                          HapticFeedback.lightImpact();
                          _caregiverCardController.forward();
                        },
                        onTapUp: (_) {
                          _caregiverCardController.reverse();
                        },
                        onTapCancel: () {
                          _caregiverCardController.reverse();
                        },
                        onTap: () {
                          // Handle Caregiver Chat navigation
                          print('Navigate to Caregiver Chat');
                        },
                        imageAsset:
                            'images/caregiver.png', // Using existing caregiver image
                      ),

                      // Bottom spacing
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// Build the header section with title
  Widget _buildHeader(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chat',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect and communicate',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDarkMode
                ? Colors.white.withOpacity(0.7)
                : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// Build individual chat card with premium styling
  Widget _buildChatCard({
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Animation<double> scale,
    required Function(TapDownDetails) onTapDown,
    required Function(TapUpDetails) onTapUp,
    required VoidCallback onTapCancel,
    required VoidCallback onTap,
    required String imageAsset,
  }) {
    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) {
        return Transform.scale(
          scale: scale.value,
          child: GestureDetector(
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            onTapCancel: onTapCancel,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 280, // Increased height significantly for premium feel
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : const Color(0xFF475569).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  if (!isDarkMode)
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                children: [
                  // Top row with image and main content
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        // Left side - Image/Icon section
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: _buildImageOrIcon(
                                imageAsset: imageAsset,
                                fallbackIcon: icon,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Right side - Text content
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.7)
                                        : const Color(0xFF475569),
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom section with features and action button
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Features row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFeatureChip(
                              isDarkMode: isDarkMode,
                              label:
                                  title.contains('AI') ? 'Instant' : 'Secure',
                              icon: title.contains('AI')
                                  ? CupertinoIcons.bolt_fill
                                  : CupertinoIcons.lock_shield_fill,
                            ),
                            _buildFeatureChip(
                              isDarkMode: isDarkMode,
                              label:
                                  title.contains('AI') ? '24/7' : 'Real-time',
                              icon: title.contains('AI')
                                  ? CupertinoIcons.clock_fill
                                  : CupertinoIcons.chat_bubble_2_fill,
                            ),
                            _buildFeatureChip(
                              isDarkMode: isDarkMode,
                              label: title.contains('AI') ? 'Smart' : 'Private',
                              icon: title.contains('AI')
                                  ? CupertinoIcons.lightbulb_fill
                                  : CupertinoIcons.eye_slash_fill,
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        // Action button
                        Container(
                          width: 440,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: title.contains('AI')
                                  ? [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF1D4ED8),
                                    ]
                                  : [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: (title.contains('AI')
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF10B981))
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onTap,
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Start Chat',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      CupertinoIcons.arrow_right,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ],
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
        );
      },
    );
  }

  /// Build image or fallback to icon
  Widget _buildImageOrIcon({
    required String imageAsset,
    required IconData fallbackIcon,
    required bool isDarkMode,
  }) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: const Color(0xFF475569).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            return Icon(
              fallbackIcon,
              size: 36,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF475569),
            );
          },
        ),
      ),
    );
  }

  /// Build feature chip for modern premium look
  Widget _buildFeatureChip({
    required bool isDarkMode,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : const Color(0xFF475569),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.8)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
