import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart' as app_colors;
import 'controllers/home_automation_controller.dart';
import 'models/home_automation_models.dart';

class RoomDetailsScreen extends StatefulWidget {
  final String roomName;
  final IconData roomIcon;
  final Color roomColor;
  final bool isDarkMode;

  const RoomDetailsScreen({
    Key? key,
    required this.roomName,
    required this.roomIcon,
    required this.roomColor,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Device> roomDevices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRoomDevices();
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

  void _loadRoomDevices() {
    // Simulate loading room devices
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        roomDevices = _getDevicesForRoom(widget.roomName);
        isLoading = false;
      });
    });
  }

  List<Device> _getDevicesForRoom(String roomName) {
    // Sample devices based on room using the existing Device model
    switch (roomName.toLowerCase()) {
      case 'living room':
        return [
          Device(
              id: '1',
              name: 'Main Light',
              type: DeviceType.light,
              roomId: 'living_room',
              status: DeviceStatus.on,
              properties: {'brightness': 75}),
          Device(
              id: '2',
              name: 'Floor Lamp',
              type: DeviceType.light,
              roomId: 'living_room',
              status: DeviceStatus.off,
              properties: {'brightness': 50}),
          Device(
              id: '3',
              name: 'TV',
              type: DeviceType.tv,
              roomId: 'living_room',
              status: DeviceStatus.on),
          Device(
              id: '4',
              name: 'Air Conditioner',
              type: DeviceType.airConditioner,
              roomId: 'living_room',
              status: DeviceStatus.on,
              properties: {'temperature': 22}),
          Device(
              id: '5',
              name: 'Router',
              type: DeviceType.router,
              roomId: 'living_room',
              status: DeviceStatus.on),
        ];
      case 'kitchen':
        return [
          Device(
              id: '6',
              name: 'Kitchen Light',
              type: DeviceType.light,
              roomId: 'kitchen',
              status: DeviceStatus.on,
              properties: {'brightness': 85}),
          Device(
              id: '7',
              name: 'Under Cabinet Lights',
              type: DeviceType.light,
              roomId: 'kitchen',
              status: DeviceStatus.off,
              properties: {'brightness': 40}),
          Device(
              id: '8',
              name: 'Exhaust Fan',
              type: DeviceType.fan,
              roomId: 'kitchen',
              status: DeviceStatus.on),
        ];
      case 'bed room':
        return [
          Device(
              id: '10',
              name: 'Bedroom Light',
              type: DeviceType.light,
              roomId: 'bedroom',
              status: DeviceStatus.off,
              properties: {'brightness': 30}),
          Device(
              id: '11',
              name: 'Bedside Lamp',
              type: DeviceType.light,
              roomId: 'bedroom',
              status: DeviceStatus.on,
              properties: {'brightness': 25}),
          Device(
              id: '12',
              name: 'Fan',
              type: DeviceType.fan,
              roomId: 'bedroom',
              status: DeviceStatus.on),
          Device(
              id: '13',
              name: 'TV',
              type: DeviceType.tv,
              roomId: 'bedroom',
              status: DeviceStatus.off),
        ];
      case 'bath room':
        return [
          Device(
              id: '14',
              name: 'Bathroom Light',
              type: DeviceType.light,
              roomId: 'bathroom',
              status: DeviceStatus.on,
              properties: {'brightness': 70}),
          Device(
              id: '15',
              name: 'Exhaust Fan',
              type: DeviceType.fan,
              roomId: 'bathroom',
              status: DeviceStatus.off),
        ];
      case 'guest room':
        return [
          Device(
              id: '17',
              name: 'Guest Light',
              type: DeviceType.light,
              roomId: 'guest_room',
              status: DeviceStatus.off,
              properties: {'brightness': 60}),
          Device(
              id: '18',
              name: 'Reading Lamp',
              type: DeviceType.light,
              roomId: 'guest_room',
              status: DeviceStatus.off,
              properties: {'brightness': 40}),
          Device(
              id: '19',
              name: 'AC Unit',
              type: DeviceType.airConditioner,
              roomId: 'guest_room',
              status: DeviceStatus.off,
              properties: {'temperature': 24}),
        ];
      default:
        return [];
    }
  }

  void _toggleDevice(Device device) {
    HapticFeedback.lightImpact();
    setState(() {
      final index = roomDevices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        roomDevices[index].togglePower();
      }
    });
    print('Toggle device: ${device.name}');
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
                  child: isLoading ? _buildLoadingState() : _buildDevicesList(),
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
      child: Column(
        children: [
          // Navigation and title
          Row(
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
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF2A2A2A),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                widget.roomName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // TODO: Add room settings
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
                    Icons.more_horiz,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF2A2A2A),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Room info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: widget.roomColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.roomIcon,
                    color: widget.roomColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${roomDevices.length} devices',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${roomDevices.where((d) => d.status == DeviceStatus.on).length} On',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF475569),
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text(
          'Devices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        ...roomDevices.map((device) => _buildDeviceCard(device)),
        const SizedBox(height: 100), // Bottom padding
      ],
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getDeviceColor(device.type).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDeviceIcon(device.type),
              color: _getDeviceColor(device.type),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
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
                  _getDeviceStatus(device),
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleDevice(device),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: device.status == DeviceStatus.on
                    ? _getDeviceColor(device.type)
                    : (widget.isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF475569).withOpacity(0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: device.status == DeviceStatus.on
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return Icons.lightbulb_outline;
      case DeviceType.thermostat:
        return Icons.thermostat;
      case DeviceType.securitySystem:
        return Icons.security;
      case DeviceType.tv:
        return Icons.tv;
      case DeviceType.fan:
        return Icons.air;
      case DeviceType.airConditioner:
        return Icons.ac_unit;
      case DeviceType.router:
        return Icons.router;
    }
  }

  Color _getDeviceColor(DeviceType type) {
    switch (type) {
      case DeviceType.light:
        return const Color(0xFFFFA726);
      case DeviceType.thermostat:
      case DeviceType.airConditioner:
        return const Color(0xFF42A5F5);
      case DeviceType.securitySystem:
        return const Color(0xFFEF5350);
      case DeviceType.tv:
        return const Color(0xFF9C27B0);
      case DeviceType.fan:
        return const Color(0xFF66BB6A);
      case DeviceType.router:
        return const Color(0xFF475569);
    }
  }

  String _getDeviceStatus(Device device) {
    if (device.status != DeviceStatus.on) return 'Off';

    switch (device.type) {
      case DeviceType.light:
        final brightness = device.getProperty<int>('brightness');
        return 'On • ${brightness ?? 100}%';
      case DeviceType.thermostat:
      case DeviceType.airConditioner:
        final temperature = device.getProperty<int>('temperature');
        if (temperature != null) {
          return 'On • ${temperature}°C';
        }
        return 'On';
      case DeviceType.fan:
        final fanSpeed = device.getProperty<int>('fanSpeed');
        if (fanSpeed != null) {
          return 'On • Speed $fanSpeed';
        }
        return 'On';
      default:
        return 'On';
    }
  }
}
