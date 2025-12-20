import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'colors.dart' as app_colors;
import 'controllers/home_automation_controller.dart';
import 'models/home_automation_models.dart';
import 'home automation/src/data/models/device_model.dart' as ha;
import 'home automation/src/logic/providers/device_providers.dart';

/// PHASE 2: RoomDetailsScreen now uses backend data.
/// Accepts roomId to fetch devices from Hive via devicesControllerProvider.
class RoomDetailsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final IconData roomIcon;
  final Color roomColor;
  final bool isDarkMode;

  const RoomDetailsScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    required this.roomIcon,
    required this.roomColor,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  ConsumerState<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends ConsumerState<RoomDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  /// Convert home automation DeviceModel to legacy Device for UI compatibility.
  Device _convertToLegacyDevice(ha.DeviceModel d) {
    return Device(
      id: d.id,
      name: d.name,
      type: _mapDeviceType(d.type),
      roomId: d.roomId,
      status: d.isOn ? DeviceStatus.on : DeviceStatus.off,
      properties: d.state,
    );
  }

  DeviceType _mapDeviceType(ha.DeviceType haType) {
    switch (haType) {
      case ha.DeviceType.bulb:
      case ha.DeviceType.lamp:
        return DeviceType.light;
      case ha.DeviceType.fan:
        return DeviceType.fan;
    }
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

  // PHASE 3: _getDevicesForRoom hardcoded data REMOVED
  // Backend is the sole source of truth - empty room = empty state

  void _toggleDevice(Device device) {
    HapticFeedback.lightImpact();
    // PHASE 2: Toggle via repository instead of local state
    final repo = ref.read(deviceRepositoryProvider);
    final newState = device.status != DeviceStatus.on;
    repo.toggleDevice(device.id, newState);
    print('Toggle device: ${device.name} -> ${newState ? "on" : "off"}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PHASE 2: Fetch devices from Hive via provider
    final devicesAsync = ref.watch(devicesControllerProvider(widget.roomId));
    
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: devicesAsync.when(
              loading: () => Column(
                children: [
                  _buildHeader(deviceCount: 0, activeCount: 0),
                  Expanded(child: _buildLoadingState()),
                ],
              ),
              error: (e, _) => Column(
                children: [
                  _buildHeader(deviceCount: 0, activeCount: 0),
                  Expanded(child: _buildErrorState(e.toString())),
                ],
              ),
              data: (haDevices) {
                // PHASE 3: Backend is authoritative - no fallback to hardcoded data
                final devices = haDevices.map(_convertToLegacyDevice).toList();
                final activeCount = devices.where((d) => d.status == DeviceStatus.on).length;
                return Column(
                  children: [
                    _buildHeader(deviceCount: devices.length, activeCount: activeCount),
                    Expanded(child: devices.isEmpty 
                        ? _buildEmptyState()
                        : _buildDevicesList(devices)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: widget.isDarkMode ? Colors.white38 : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices in this room',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add devices to control them from here',
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Text(
        'Error loading devices: $error',
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildHeader({required int deviceCount, required int activeCount}) {
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
                        '$deviceCount devices',
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
                    '$activeCount On',
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

  Widget _buildDevicesList(List<Device> roomDevices) {
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
