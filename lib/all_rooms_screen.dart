import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'colors.dart' as app_colors;
import 'room_details_screen.dart';
import 'providers/domain_providers.dart';
import 'widgets/sync_status_banner.dart';

/// AllRoomsScreen - PHASE 2 COMPLIANT
///
/// Data Flow:
/// UI → roomListProvider → HomeAutomationRepository → BoxAccessor.rooms() → Hive
///
/// ❌ REMOVED: Hardcoded allRooms list
/// ✅ ADDED: Provider-backed reactive data
class AllRoomsScreen extends ConsumerStatefulWidget {
  final bool isDarkMode;

  const AllRoomsScreen({
    super.key,
    required this.isDarkMode,
  });

  @override
  ConsumerState<AllRoomsScreen> createState() => _AllRoomsScreenState();
}

class _AllRoomsScreenState extends ConsumerState<AllRoomsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch rooms from provider - reactive!
    final roomsAsync = ref.watch(roomListProvider);
    final automationState = ref.watch(automationStateProvider);

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Sync status banner - STEP 2.6
                const SyncStatusBanner(),
                _buildHeader(),
                Expanded(
                  child: roomsAsync.when(
                    data: (rooms) => _buildRoomsContent(rooms, automationState),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading rooms: $e'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(roomListProvider),
                            child: const Text('Retry'),
                          ),
                        ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF2A2A2A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color:
                    widget.isDarkMode ? Colors.white : const Color(0xFF2A2A2A),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'All Rooms',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // TODO: Add rooms management
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF2A2A2A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add,
                color:
                    widget.isDarkMode ? Colors.white : const Color(0xFF2A2A2A),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsContent(List<dynamic> rooms, AsyncValue<AutomationState> automationAsync) {
    final autoState = automationAsync.valueOrNull;
    final totalDevices = autoState?.totalDevices ?? 0;
    final activeDevices = autoState?.activeDevices ?? 0;
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Summary section - NOW USES PROVIDER DATA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : const Color(0xFF475569).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStat('Rooms', '${rooms.length}', Colors.blue),
                  const SizedBox(width: 24),
                  _buildStat('Total Devices', '$totalDevices', Colors.green),
                  const SizedBox(width: 24),
                  _buildStat('Active', '$activeDevices', Colors.orange),
                ],
              ),
            ],
          ),
        ),

        // Rooms grid
        Text(
          'Rooms',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        rooms.isEmpty 
            ? _buildEmptyState()
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return _buildRoomGridCardFromModel(room);
                },
              ),
        const SizedBox(height: 100), // Bottom padding
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.house,
            size: 64,
            color: widget.isDarkMode ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Rooms Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first room to get started',
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white60 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: widget.isDarkMode
                ? Colors.white.withOpacity(0.6)
                : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  /// @deprecated Use _buildRoomGridCardFromModel instead
  /// This method is kept temporarily for reference but should not be used.
  Widget _buildRoomGridCard_DEPRECATED(Map<String, dynamic> room) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RoomDetailsScreen(
              roomId: room['id'] ?? '',
              roomName: room['name'],
              roomIcon: room['icon'],
              roomColor: room['color'],
              isDarkMode: widget.isDarkMode,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        print('Navigate to room: ${room['name']}');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : const Color(0xFF475569).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: room['color'].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    room['icon'],
                    color: room['color'],
                    size: 24,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: room['activeDevices'] > 0
                        ? Colors.green.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${room['activeDevices']} On',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: room['activeDevices'] > 0
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            // Room info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room['devices'],
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build room card from RoomModel (provider-backed data)
  Widget _buildRoomGridCardFromModel(dynamic room) {
    // Get room properties with defaults
    final String id = room.id ?? '';
    final String name = room.name ?? 'Room';
    final String iconId = room.iconId ?? 'house';
    final int colorValue = room.color ?? 0xFF3B82F6;
    final Color roomColor = Color(colorValue);
    final IconData icon = _iconFromId(iconId);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RoomDetailsScreen(
              roomId: id,
              roomName: name,
              roomIcon: icon,
              roomColor: roomColor,
              isDarkMode: widget.isDarkMode,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : const Color(0xFF475569).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: roomColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: roomColor,
                    size: 24,
                  ),
                ),
              ],
            ),

            // Room info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convert icon ID to IconData
  IconData _iconFromId(String iconId) {
    switch (iconId.toLowerCase()) {
      case 'house':
      case 'living':
      case 'sofa':
        return CupertinoIcons.house;
      case 'kitchen':
      case 'utensils':
        return CupertinoIcons.scissors;
      case 'bed':
      case 'bedroom':
        return CupertinoIcons.bed_double;
      case 'bath':
      case 'bathroom':
      case 'drop':
        return CupertinoIcons.drop;
      case 'guest':
      case 'person':
        return CupertinoIcons.person_2;
      case 'garage':
      case 'car':
        return CupertinoIcons.car;
      default:
        return CupertinoIcons.house;
    }
  }
}
