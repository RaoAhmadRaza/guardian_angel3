import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'colors.dart' as app_colors;
import 'room_details_screen.dart';

class AllRoomsScreen extends StatefulWidget {
  final bool isDarkMode;

  const AllRoomsScreen({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AllRoomsScreen> createState() => _AllRoomsScreenState();
}

class _AllRoomsScreenState extends State<AllRoomsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // All rooms data
  final List<Map<String, dynamic>> allRooms = [
    {
      'name': 'Living Room',
      'icon': CupertinoIcons.house,
      'devices': '5 Devices',
      'color': const Color(0xFF3B82F6),
      'activeDevices': 3,
    },
    {
      'name': 'Kitchen',
      'icon': CupertinoIcons.scissors,
      'devices': '3 Devices',
      'color': const Color(0xFFEAB308),
      'activeDevices': 1,
    },
    {
      'name': 'Bed Room',
      'icon': CupertinoIcons.bed_double,
      'devices': '4 Devices',
      'color': const Color(0xFF8B5CF6),
      'activeDevices': 2,
    },
    {
      'name': 'Bath Room',
      'icon': CupertinoIcons.drop,
      'devices': '3 Devices',
      'color': const Color(0xFF10B981),
      'activeDevices': 1,
    },
    {
      'name': 'Guest Room',
      'icon': CupertinoIcons.person_2,
      'devices': '3 Devices',
      'color': const Color(0xFFF59E0B),
      'activeDevices': 0,
    },
    {
      'name': 'Garage',
      'icon': CupertinoIcons.car,
      'devices': '2 Devices',
      'color': const Color(0xFF6B7280),
      'activeDevices': 1,
    },
  ];

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
                _buildHeader(),
                Expanded(
                  child: _buildRoomsGrid(),
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

  Widget _buildRoomsGrid() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Summary section
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
                  _buildStat('Rooms', '${allRooms.length}', Colors.blue),
                  const SizedBox(width: 24),
                  _buildStat(
                      'Total Devices', '${_getTotalDevices()}', Colors.green),
                  const SizedBox(width: 24),
                  _buildStat('Active', '${_getActiveDevices()}', Colors.orange),
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: allRooms.length,
          itemBuilder: (context, index) {
            final room = allRooms[index];
            return _buildRoomGridCard(room);
          },
        ),
        const SizedBox(height: 100), // Bottom padding
      ],
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

  Widget _buildRoomGridCard(Map<String, dynamic> room) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RoomDetailsScreen(
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

  int _getTotalDevices() {
    // Calculate total devices from all rooms
    int total = 0;
    for (var room in allRooms) {
      String deviceStr = room['devices'];
      int devices = int.parse(deviceStr.split(' ')[0]);
      total += devices;
    }
    return total;
  }

  int _getActiveDevices() {
    // Calculate total active devices
    int total = 0;
    for (var room in allRooms) {
      total += room['activeDevices'] as int;
    }
    return total;
  }
}
