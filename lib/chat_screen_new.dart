import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'theme/colors.dart' show AppColors;
import 'individual_chat_screen.dart';

/// Chat list screen showing active users and recent conversations
/// Implements full light/dark theme support per UI analysis documentation
class ChatScreenNew extends StatefulWidget {
  const ChatScreenNew({super.key});

  @override
  State<ChatScreenNew> createState() => _ChatScreenNewState();
}

class _ChatScreenNewState extends State<ChatScreenNew> with SingleTickerProviderStateMixin {
  
  bool _isListening = false; // Voice accessibility state
  // Removed SOS state and animation
  // Search state
  final TextEditingController _searchController = TextEditingController(); // retained for future search reactivation
  bool _isSosPressed = false;
  // Category filtering
  final List<String> _categories = const [
    'All', 'Therapist', 'Caregiver', 'Community', 'Peace of Mind'
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // bottom nav removed; no controller initialization needed
  }

  @override
  void dispose() {
    // no bottom nav controller to dispose
    super.dispose();
  }

  // Mock data for active users (horizontal scrollable section)
  final List<Map<String, dynamic>> activeUsers = [
    {
      'name': 'Joy',
      'avatar': 'https://i.pravatar.cc/150?img=33',
      'color': const Color(0xFF4DD4E8),
      'mood': 'happy',
      'vitals': 'stable',
      'heartRate': 71,
    },
    {
      'name': 'Sai',
      'avatar': 'https://i.pravatar.cc/150?img=45',
      'color': const Color(0xFF7CDAA5),
      'mood': 'calm',
      'vitals': 'stable',
      'heartRate': 69,
    },
    {
      'name': 'Vysh',
      'avatar': 'https://i.pravatar.cc/150?img=47',
      'color': const Color(0xFFD94D8C),
      'mood': 'stressed',
      'vitals': 'irregular',
      'heartRate': 96,
    },
    {
      'name': 'Jay',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'color': const Color(0xFF6B5FED),
      'mood': 'calm',
      'vitals': 'fallAlert',
      'heartRate': 88,
    },
  ];

  // Mock data for chat conversations
  final List<Map<String, dynamic>> chats = [
    {
      'name': 'Vysh',
      'message': 'Stable | HR 72 bpm',
      'time': '12:42 PM',
      'avatar': 'https://i.pravatar.cc/150?img=47',
      'unreadCount': 1,
      'isRead': false,
      'mood': 'calm',
      'vitals': 'stable',
      'heartRate': 72,
      'statusText': 'Stable | HR 72 bpm',
      'category': 'therapist',
      'crisis': false,
    },
    {
      'name': 'Jay',
      'message': 'Feeling low 😔',
      'time': '11:56 AM',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'unreadCount': 0,
      'isRead': true,
      'hasCheckMark': true,
      'mood': 'stressed',
      'vitals': 'irregular',
      'heartRate': 94,
      'statusText': 'Feeling low 😔',
      'category': 'caregiver',
      'crisis': true,
      'lastHeartbeat': 94,
      'geoTimestamp': '10:42',
    },
    {
      'name': 'Sai',
      'message': 'Emotion-triggered alert: pending caregiver review.',
      'time': 'Today',
      'avatar': 'https://i.pravatar.cc/150?img=45',
      'unreadCount': 0,
      'isRead': false,
      'mood': 'neutral',
      'vitals': 'fallAlert',
      'heartRate': 82,
      'statusText': 'Emotion-triggered alert: pending caregiver review.',
      'category': 'peace',
      'crisis': true,
    },
    {
      'name': 'Joy',
      'message': 'Stable | HR 69 bpm',
      'time': 'Yesterday',
      'avatar': 'https://i.pravatar.cc/150?img=33',
      'unreadCount': 0,
      'isRead': true,
      'hasDoubleCheck': true,
      'mood': 'happy',
      'vitals': 'stable',
      'heartRate': 69,
      'statusText': 'Stable | HR 69 bpm',
      'category': 'community',
      'crisis': false,
    },
    {
      'name': 'Tejas',
      'message': 'Stable | HR 74 bpm',
      'time': '03/08/2025',
      'avatar': 'https://i.pravatar.cc/150?img=56',
      'unreadCount': 0,
      'isRead': true,
      'hasDoubleCheck': true,
      'isDelivered': true,
      'mood': 'calm',
      'vitals': 'stable',
      'heartRate': 74,
      'statusText': 'Stable | HR 74 bpm',
      'category': 'therapist',
      'crisis': false,
    },
    {
      'name': 'Bhanu',
      'message': 'Emotion-triggered alert: pending caregiver review.',
      'time': '01/08/2025',
      'avatar': 'https://i.pravatar.cc/150?img=43',
      'unreadCount': 0,
      'isRead': false,
      'mood': 'stressed',
      'vitals': 'irregular',
      'heartRate': 98,
      'statusText': 'Emotion-triggered alert: pending caregiver review.',
      'category': 'caregiver',
      'crisis': false,
      'lastHeartbeat': 98,
      'geoTimestamp': '09:58',
    },
  ];


  // -------------------------------------------------------------
  // Helper: Vitals badge color mapping
  // -------------------------------------------------------------
  Color _getVitalsBadgeColor(String vitals) {
    switch (vitals) {
      case 'stable':
        return const Color(0xFF10B981); // green
      case 'irregular':
        return const Color(0xFFFACC15); // yellow
      case 'fallAlert':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF64748B); // neutral gray
    }
  }

  // -------------------------------------------------------------
  // Helper: Status text color logic (prioritize alerts)
  // -------------------------------------------------------------
  Color _getStatusColor(bool isDarkMode, String vitals, String? statusText) {
    // If specific alert phrases appear, force alert coloring
    if (statusText != null) {
      final lower = statusText.toLowerCase();
      if (lower.contains('alert') || lower.contains('caregiver')) {
        return const Color(0xFFEF4444); // critical red
      }
      if (lower.contains('feeling low')) {
        return isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      }
    }
    switch (vitals) {
      case 'fallAlert':
        return const Color(0xFFEF4444);
      case 'irregular':
        return isDarkMode ? const Color(0xFFFACC15) : const Color(0xFFCA8A04);
      case 'stable':
        return isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
      default:
        return isDarkMode ? Colors.white.withOpacity(0.7) : AppColors.lightTextSecondary;
    }
  }

  // -------------------------------------------------------------
  // Helper: Smart preview generation based on vitals/mood/category
  // -------------------------------------------------------------
  String _getSmartPreview({
    required String category,
    required String vitals,
    required String mood,
    String? statusText,
    required int unreadCount,
    String? message,
  }) {
    final cat = category.toLowerCase();
    final m = mood.toLowerCase();
    final v = vitals.toLowerCase();
    final stLower = statusText?.toLowerCase() ?? '';

    // High-priority health alerts first
    if (v == 'fallalert') return 'Guardian Angel: Fall alert triggered.';
    if (v == 'irregular') return 'Guardian Angel: Detected irregular heartbeat.';

    // Emotional state guidance
    if (stLower.contains('feeling low') || m == 'stressed') {
      return 'PeaceBot: You seem anxious today. Shall we meditate?';
    }

    // Category-specific intents
    if (cat == 'therapist' && stLower.contains('drip')) {
      return 'Therapist Nurse: Your drip alert was acknowledged.';
    }
    if (cat == 'community' && unreadCount > 0) {
      return 'Community: You have new support messages.';
    }
    if (cat == 'peace') {
      return 'PeaceBot: Daily check-in available now.';
    }

    // Fallbacks: provided status, then message
    if ((statusText ?? '').isNotEmpty) return statusText!;
    return message ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFFDFDFD),
      extendBody: true,
      body: Stack(
        children: [
          // Main content with gradient
          Container(
            decoration: BoxDecoration(
              // Calming sky gradient background in light mode; keep rich depth in dark
              gradient: isDarkMode
                  ? AppColors.getPrimaryGradient(Brightness.dark)
                  : AppColors.guardianAngelSkyGradient,
            ),
            child: Column(
              children: [
                // Header section with gradient background
                _buildHeader(isDarkMode),

                // Chat list section
                Expanded(
                  child: _buildChatList(isDarkMode),
                ),
              ],
            ),
          ),
          // Listening chip near the FAB when active
          if (_isListening)
            Positioned(
              right: 88,
              bottom: 86,
              child: _buildListeningChip(isDarkMode),
            ),
          // SOS floating button
          Positioned(
            right: 16,
            bottom: 160,
            child: GestureDetector(
              onLongPressStart: (_) => setState(() => _isSosPressed = true),
              onLongPressEnd: (_) {
                setState(() => _isSosPressed = false);
                _triggerSOS();
              },
              onTap: _triggerSOS,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isSosPressed
                      ? const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFEF4444)])
                      : (isDarkMode
                          ? const LinearGradient(colors: [Color(0xFF2C2C2E), Color(0xFF2C2C2E)])
                          : const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF0F172A)])),
                  boxShadow: [
                    BoxShadow(
                      color: _isSosPressed
                          ? const Color(0xFFFF3B30).withOpacity(0.45)
                          : Colors.black.withOpacity(isDarkMode ? 0.25 : 0.15),
                      blurRadius: _isSosPressed ? 20 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      // Bottom navigation bar removed as per request
      // Floating voice button: Speak to Angel
      floatingActionButton: Semantics(
        label: 'Speak to Angel',
        hint: 'Double tap and hold to speak a command',
        button: true,
        child: GestureDetector(
          onLongPressStart: (_) => _startVoiceListening(),
          onLongPressEnd: (_) => _stopVoiceListening(),
          onTap: () {
            // Gentle guidance on tap
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press and hold to speak to your Guardian Angel'),
                duration: Duration(milliseconds: 1200),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isListening
                  ? AppColors.guardianAngelSkyGradient
                  : (isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF2C2C2E), Color(0xFF2C2C2E)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF0F172A)],
                        )),
              boxShadow: [
                BoxShadow(
                  color: _isListening
                      ? const Color(0xFF69A7FF).withOpacity(0.45)
                      : Colors.black.withOpacity(isDarkMode ? 0.25 : 0.15),
                  blurRadius: _isListening ? 20 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _isListening ? CupertinoIcons.mic_circle_fill : CupertinoIcons.mic_solid,
              color: _isListening
                  ? const Color(0xFF0F172A)
                  : (isDarkMode ? Colors.white : const Color(0xFFFDFDFD)),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  // Accessibility listening chip UI
  Widget _buildListeningChip(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF3C3C3E) : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.25)
                : const Color(0xFF475569).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.waveform,
            size: 16,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
          const SizedBox(width: 8),
          Text(
            'Listening…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _startVoiceListening() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() => _isListening = true);
  }

  void _stopVoiceListening() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() => _isListening = false);
    // TODO: Hook into voice command parser: e.g., "I don’t feel well", "Contact therapist", "SOS"
  }

  // Aggregate health snapshot (across active users)
  void _showHealthSnapshotAggregate(BuildContext context) {
    String derivedMood = 'calm';
    if (activeUsers.isNotEmpty) {
      final moods = activeUsers.map((u) => (u['mood'] as String?)?.toLowerCase() ?? '').toList();
      if (moods.contains('stressed')) {
        derivedMood = 'stressed';
      } else if (moods.contains('neutral')) {
        derivedMood = 'neutral';
      } else if (moods.contains('happy')) {
        derivedMood = 'happy';
      }
    }
    int? avgHr;
    if (activeUsers.isNotEmpty) {
      final rates = activeUsers.map((u) => u['heartRate'] as int).where((r) => r > 0).toList();
      if (rates.isNotEmpty) avgHr = (rates.reduce((a, b) => a + b) / rates.length).round();
    }
    final String hrLabel = avgHr != null ? '$avgHr bpm' : '—';
    const String o2 = '97%';
    const String sleep = 'Good';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📊'),
                  const SizedBox(width: 8),
                  Text('Health Snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    onPressed: () => Navigator.of(ctx).pop(),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _snapshotTile(isDark, 'Heart Rate', hrLabel, CupertinoIcons.heart_fill)),
                  const SizedBox(width: 8),
                  Expanded(child: _snapshotTile(isDark, 'SpO₂', o2, CupertinoIcons.waveform_path_ecg)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _snapshotTile(isDark, 'Sleep', sleep, CupertinoIcons.bed_double)),
                  const SizedBox(width: 8),
                  Expanded(child: _snapshotTile(isDark, 'Mood', derivedMood[0].toUpperCase() + derivedMood.substring(1), CupertinoIcons.smiley)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _snapshotTile(bool isDark, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3C3C3E) : AppColors.lightBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white : const Color(0xFF475569)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _triggerSOS() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS sent. Care team alerted.'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  /// Build header section with gradient background and active users
  Widget _buildHeader(bool isDarkMode) {
    final double topPad = MediaQuery.of(context).padding.top + 24; // Safe-area informed top spacing
    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2C2C2E),
                  Color(0xFF1C1C1E),
                ],
              )
            : AppColors.guardianAngelSkyGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF475569).withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header content (title & tagline removed per request)
          Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Directly show context ribbon & controls after safe-area padding
                  _buildEmotionContextRibbon(isDarkMode),
                  const SizedBox(height: 16), // spacing before categories
                  _buildCategorySegment(isDarkMode),
                  const SizedBox(height: 12),
                ],
              ),
            ),
                      ),
          

          // Search bar with "Ask Internet" integration
          const SizedBox(height: 8), // spacing before search bar (top margin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // iOS-style search bar
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    // onChanged disabled until search refactor returns
                    onChanged: (_) {},
                    placeholder: 'Search',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                    placeholderStyle: TextStyle(
                      fontSize: 15,
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6B7280),
                    ),
                    prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                    suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                    backgroundColor: isDarkMode
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
                // Search results temporarily disabled pending refactor for new identity features
              ],
            ),
          ),

          const SizedBox(height: 16), // spacing above Active title per spec

          // Active users section
          _buildActiveUsersSection(isDarkMode),

          const SizedBox(height: 20), // bottom margin after active row per spec
        ],
      ),
    );
  }

  /// Build "Active" label with green indicator and horizontal scrollable user avatars
  Widget _buildActiveUsersSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Active" label with green dot
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Text(
                'Active',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Green active indicator
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Horizontal scrollable active users (reduced overall height)
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: activeUsers.length,
            itemBuilder: (context, index) {
              final user = activeUsers[index];
              return _buildActiveUserAvatar(
                name: user['name'],
                avatarUrl: user['avatar'],
                backgroundColor: user['color'],
                isDarkMode: isDarkMode,
                mood: user['mood'] ?? 'calm',
                vitals: user['vitals'] ?? 'stable',
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build individual active user avatar with name
  Widget _buildActiveUserAvatar({
    required String name,
    required String avatarUrl,
    required Color backgroundColor,
    required bool isDarkMode,
    String mood = 'calm',
    String vitals = 'stable',
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 14), // 14px gap between avatars
      child: Column(
        children: [
          // Mood ring wrapper
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Status-aware glow around avatar
                    BoxShadow(
                      color: AppColors.getStatusShadowColor(
                        vitals: vitals,
                        mood: mood,
                        crisis: false,
                      ).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Vitals badge (micro indicator)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getVitalsBadgeColor(vitals),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500, // medium weight
              color: Colors.white.withOpacity(0.70), // 70% white
            ),
          ),
        ],
      ),
    );
  }

  /// Build scrollable chat list with theme-aware styling
  Widget _buildChatList(bool isDarkMode) {
    // Filter chats by selected category (map display names to internal keys)
    final filtered = chats.where((chat) {
      if (_selectedCategory == 'All') return true;
      final cat = chat['category']?.toString().toLowerCase();
      switch (_selectedCategory) {
        case 'Therapist':
          return cat == 'therapist';
        case 'Caregiver':
          return cat == 'caregiver';
        case 'Community':
          return cat == 'community';
        case 'Peace of Mind':
          return cat == 'peace';
        default:
          return true;
      }
    }).toList();
  // Sort: crisis chats pinned to top (SOS removed)
    filtered.sort((a, b) {
      final ac = a['crisis'] == true ? 1 : 0;
      final bc = b['crisis'] == true ? 1 : 0;
      if (ac != bc) return bc.compareTo(ac); // crisis first
      return 0; // keep existing order otherwise
    });
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFDFDFD),
      ),
      child: filtered.isEmpty
          ? Center(
              child: Text(
                'No conversations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? const Color(0xFF8E8E93)
                      : AppColors.lightTextSecondary,
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(
                top: 8,
                // Add extra space so the last chat isn't obscured by the bottom nav bar
                bottom: MediaQuery.of(context).padding.bottom + 110,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final chat = filtered[index];
                final smartPreview = _getSmartPreview(
                  category: (chat['category'] ?? 'caregiver').toString(),
                  vitals: (chat['vitals'] ?? 'stable').toString(),
                  mood: (chat['mood'] ?? 'calm').toString(),
                  statusText: chat['statusText']?.toString(),
                  unreadCount: (chat['unreadCount'] ?? 0) as int,
                  message: chat['message']?.toString(),
                );
                return _buildChatListItem(
                  name: chat['name'],
                  message: chat['message'],
                  time: chat['time'],
                  avatarUrl: chat['avatar'],
                  unreadCount: chat['unreadCount'],
                  isRead: chat['isRead'],
                  hasCheckMark: chat['hasCheckMark'] ?? false,
                  hasDoubleCheck: chat['hasDoubleCheck'] ?? false,
                  isDelivered: chat['isDelivered'] ?? false,
                  isDarkMode: isDarkMode,
                  mood: chat['mood'] ?? 'calm',
                  vitals: chat['vitals'] ?? 'stable',
                  statusText: smartPreview,
                  crisis: chat['crisis'] == true,
                  lastHeartbeat: chat['lastHeartbeat'],
                  geoTimestamp: chat['geoTimestamp'],
                  category: chat['category'],
                );
              },
            ),
    );
  }

  // Segmented category control
  Widget _buildCategorySegment(bool isDarkMode) {
    // 3-up / 2-down layout: first three categories on top row, remaining two centered below.
    final topRow = _categories.take(3).toList();
    final bottomRow = _categories.skip(3).toList();

    Widget buildPill(String cat) {
      final bool selected = _selectedCategory == cat;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = cat);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? AppColors.guardianAngelLavenderGradient
                : null,
            color: selected
                ? null
                : (isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFB9A6FF).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDarkMode ? const Color(0xFF3C3C3E) : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              cat,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? const Color(0xFF0F172A)
                    : (isDarkMode ? const Color(0xFF8E8E93) : AppColors.lightTextSecondary),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top row: 3 pills evenly spaced
        Row(
          children: topRow
              .map((c) => Expanded(child: buildPill(c)))
              .toList(),
        ),
        // Bottom row: 2 pills centered under the 3 above
        Row(
          children: const [],
        ),
        Row(
          children: [
            const Spacer(flex: 1),
            Expanded(flex: 4, child: buildPill(bottomRow[0])),
            Expanded(flex: 4, child: buildPill(bottomRow[1])),
            const Spacer(flex: 1),
          ],
        ),
      ],
    );
  }

  // Emotion Context Ribbon summarizing mood, sleep, and heart rate
  Widget _buildEmotionContextRibbon(bool isDarkMode) {
    // Simplified header per request: only title and analytics button.
    return Row(
      children: [
        Text(
          'Angel Chat',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showHealthSnapshotAggregate(context),
          child: Tooltip(
            message: 'Health snapshot',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDarkMode ? const Color(0xFF3C3C3E) : AppColors.lightBorder),
              ),
              child: const Text('📊', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  // Deprecated search helper widgets removed (search results feature temporarily disabled)

  /// Build individual chat list item with theme-aware colors and glassmorphism
  Widget _buildChatListItem({
    required String name,
    required String message,
    required String time,
    required String avatarUrl,
    required int unreadCount,
    required bool isRead,
    required bool isDarkMode,
    bool hasCheckMark = false,
    bool hasDoubleCheck = false,
    bool isDelivered = false,
    String mood = 'calm',
    String vitals = 'stable',
    String? statusText,
    bool crisis = false,
    int? lastHeartbeat,
    String? geoTimestamp,
    String? category,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => IndividualChatScreen(
              name: name,
              avatarUrl: avatarUrl,
              mood: mood,
              vitals: vitals,
              crisis: crisis,
              statusText: statusText,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // card margin per spec
        padding: const EdgeInsets.all(14), // inner padding per spec
        decoration: BoxDecoration(
          // Always use neutral surface; use border/shadow for cues instead of full background
          color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(20), // radius per spec
          // Remove colorful borders; keep neutral or none
          border: Border.all(
            color: isDarkMode ? const Color(0xFF3C3C3E) : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: [
            // Base subtle elevation
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
            // State accent via colored shadow instead of border
            if (!crisis)
              BoxShadow(
                color: () {
                  switch (vitals) {
                    case 'stable':
                      return const Color(0xFF10B981).withOpacity(0.16);
                    case 'irregular':
                      return const Color(0xFFFACC15).withOpacity(0.14);
                    case 'fallAlert':
                      return const Color(0xFFEF4444).withOpacity(0.14);
                    default:
                      return (isDarkMode
                              ? Colors.black.withOpacity(0.12)
                              : const Color(0xFF475569).withOpacity(0.05));
                  }
                }(),
                offset: const Offset(0, 2),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            // Crisis soft red glow around edges
            if (crisis)
              BoxShadow(
                color: const Color(0xFFFF3B30).withOpacity(0.25),
                offset: const Offset(0, 3),
                blurRadius: 16,
                spreadRadius: 0,
              ),
          ],
        ),
        child: Row(
          children: [
            // Avatar without colorful ring; use soft mood-colored shadow instead
            Stack(
              clipBehavior: Clip.none,
              children: [
                Hero(
                  tag: 'avatar_$name',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? const Color(0xFF3C3C3E) : const Color(0xFFF5F5F7),
                      boxShadow: [
                        // Status-aware subtle glow
                        BoxShadow(
                          color: AppColors.getStatusShadowColor(
                            vitals: vitals,
                            mood: mood,
                            crisis: crisis,
                          ).withOpacity(0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode
                                    ? const Color(0xFF8E8E93)
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: _getVitalsBadgeColor(vitals),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Name and message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Status line replacing message preview
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasCheckMark || hasDoubleCheck || isDelivered) ...[
                        Icon(
                          hasDoubleCheck || isDelivered
                              ? CupertinoIcons.checkmark_alt_circle_fill
                              : CupertinoIcons.checkmark_alt,
                          size: 14,
                          color: isDelivered
                              ? const Color(0xFF10B981)
                              : isDarkMode
                                  ? const Color(0xFF8E8E93)
                                  : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          statusText ?? message,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(isDarkMode, vitals, statusText),
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (category != null && category.toLowerCase() == 'caregiver') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.heart_fill,
                          size: 13,
                          color: isDarkMode
                              ? const Color(0xFF10B981)
                              : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'HB ${lastHeartbeat ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.8)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          CupertinoIcons.location_solid,
                          size: 13,
                          color: isDarkMode
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          geoTimestamp != null ? 'Geo ${geoTimestamp}' : 'Geo -',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? const Color(0xFF8E8E93)
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Time and unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? const Color(0xFF8E8E93)
                        : AppColors.lightTextTertiary,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFAD961),
                          Color(0xFFF6C23A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFAD961).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // SOS indicator removed per request
}
