import 'dart:ui'; // Add this import for ImageFilter if needed, though not explicitly used yet, good for glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/patient_service.dart';
import 'src/data/home_automation_hive_bridge.dart';
import 'src/data/local_hive_service.dart';
// Host app will import these directly where needed.
import 'src/logic/providers/room_providers.dart';
import 'src/logic/providers/device_providers.dart';
import 'src/logic/providers/weather_location_providers.dart';
import 'src/data/models/device_model.dart' as domain;
import 'navigation/drawer_wrapper.dart';

// --- THEME COLORS ---

class _ScreenColors {
  final bool isDark;

  _ScreenColors(this.isDark);

  static _ScreenColors of(BuildContext context) {
    return _ScreenColors(Theme.of(context).brightness == Brightness.dark);
  }

  // 1. Foundation
  Color get bgPrimary => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFDFDFD);
  Color get bgSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get surfacePrimary => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get surfaceSecondary => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get surfaceGlass => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : Colors.white.withOpacity(0.5); // Fallback for light
  Color get borderSubtle => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF).withOpacity(0.30);
  List<BoxShadow> get shadowCard => isDark 
      ? [BoxShadow(color: const Color(0xFF000000).withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 6))]
      : [BoxShadow(color: const Color(0xFF475569).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))];

  // 2. Containers
  Color get containerDefault => isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  Color get containerHighlight => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get containerSlot => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF5F5F7);
  Color get containerSlotAlt => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFE0E0E2);
  Color get overlayModal => isDark ? const Color(0xFF1A1A1A).withOpacity(0.80) : const Color(0xFFFFFFFF).withOpacity(0.80);

  // 3. Typography
  Color get textPrimary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get textTertiary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.50) : const Color(0xFF64748B);
  Color get textInverse => isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
  Color get textLink => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  // 4. Iconography
  Color get iconPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.70) : const Color(0xFF475569);
  Color get iconSecondary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.40) : const Color(0xFF94A3B8);
  Color get iconBgPrimary => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFF5F5F7);
  Color get iconBgActive => isDark ? const Color(0xFFFFFFFF).withOpacity(0.10) : const Color(0xFFFFFFFF);

  // 5. Interactive
  Color get actionPrimaryBg => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
  Color get actionPrimaryFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.80) : const Color(0xFF475569);
  Color get actionHover => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF8FAFC);
  Color get actionPressed => isDark ? const Color(0xFF000000).withOpacity(0.20) : const Color(0xFFE2E8F0);
  Color get actionDisabledBg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.05) : const Color(0xFFF1F5F9);
  Color get actionDisabledFg => isDark ? const Color(0xFFFFFFFF).withOpacity(0.30) : const Color(0xFF94A3B8);

  // 6. Status
  Color get statusSuccess => isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  Color get statusWarning => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get statusError => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get statusInfo => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get statusNeutral => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

  // 7. Input
  Color get inputBg => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFEFEFE);
  Color get inputBorder => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
  Color get inputBorderFocus => isDark ? const Color(0xFFF8F9FA) : const Color(0xFF3B82F6);
  Color get controlActive => isDark ? const Color(0xFFF5F5F5) : const Color(0xFF2563EB);
  Color get controlTrack => isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
}

// Removed standalone main(); initialization will be invoked from Guardian Angel root.

/// Testable entrypoint which accepts provider overrides (used by tests).
/// Pass overrides to override providers (in-memory Hive, MockDriver, etc).
Future<void> mainCommon({List<Override> overrides = const []}) async {
  // Hive is initialized and adapters are registered by the host app's HiveService.
  // Use the shared bridge to open Home Automation boxes idempotently.
  await HomeAutomationHiveBridge.open();
  _automationOverrides = overrides; // store for later ProviderScope usage
}

// Stored overrides so host app can apply them when building ProviderScope.
List<Override> _automationOverrides = const [];
List<Override> get automationOverrides => _automationOverrides;

// Internal bootstrap widget logic moved to host app; original MyApp removed.

class HomeAutomationScreen extends StatefulWidget {
  const HomeAutomationScreen({super.key});

  @override
  State<HomeAutomationScreen> createState() => _HomeAutomationScreenState();
}

class _HomeAutomationScreenState extends State<HomeAutomationScreen>
    with SingleTickerProviderStateMixin {
  // Legacy dummy state removed; devices now come from Riverpod providers

  late AnimationController _menuAnimationController;
  
  // Patient data
  String _patientName = 'Patient';
  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadPatientData();
  }
  
  Future<void> _loadPatientData() async {
    final name = await PatientService.instance.getPatientName();
    final gender = await PatientService.instance.getPatientGender();
    if (mounted) {
      setState(() {
        _patientName = name.isNotEmpty ? name : 'Patient';
        _gender = gender.toLowerCase();
      });
    }
  }

  @override
  void dispose() {
    _menuAnimationController.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    // Access the DrawerWrapper's toggle function
    final drawerState = DrawerWrapper.of(context);
    if (drawerState != null) {
      // Check state BEFORE toggling
      final wasOpen = drawerState.isDrawerOpen;
      drawerState.toggleDrawer();
      // Sync animation with drawer state
      if (wasOpen) {
        // Drawer is closing, animate back to menu icon
        _menuAnimationController.reverse();
      } else {
        // Drawer is opening, animate to close icon
        _menuAnimationController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ScreenColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: Container(
        decoration: BoxDecoration(
          color: colors.bgPrimary,
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Fixed Header
            Container(
             height: 320,
             decoration: BoxDecoration(
               color: colors.bgSecondary,
               borderRadius: const BorderRadius.only(
                 bottomLeft: Radius.circular(32),
                 bottomRight: Radius.circular(32),
               ),
             ),
             child: Padding(
               // Reduced top padding (was 64) to remove SafeArea-like gap
               padding: const EdgeInsets.only(left: 24, top: 89, right: 24),
               child: Column(
                 children: [
                   _buildHeader(),
                   const SizedBox(height: 22),
                   _buildWeatherCard(),
                 ],
               ),
             ),
           ),

           Padding(
             padding: const EdgeInsets.only(top: 290.0, left: 40.0),
             child: Positioned(
               child: _buildActionButtons()),
           ),

           Padding(
             padding: const EdgeInsets.only(top: 390.0),
             child: Positioned(
              
              child: // Scrollable Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.bgPrimary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                           
                              const SizedBox(height: 32),
                              _buildDevicesHeader(),
                              
                              _buildDevicesGrid(),
                              
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
             ),
           )

                          
            
            
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = _ScreenColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleDrawer,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _menuAnimationController,
              color: colors.iconPrimary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.borderSubtle,
              width: 2,
            ),
            image: DecorationImage(
              image: AssetImage(
                _gender == 'female' ? 'images/female.jpg' : 'images/male.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome home,',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _patientName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    final colors = _ScreenColors.of(context);
    return Consumer(builder: (context, ref, _) {
      final weatherAsync = ref.watch(currentWeatherProvider);
      final placeAsync = ref.watch(reverseGeocodeProvider);
      return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: colors.shadowCard,
      ),
        child: Row(
          children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.shadowCard.first.color.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDB462),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFDB462).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(builder: (_) {
                  return placeAsync.when(
                    loading: () => Text(
                      'Locating…',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                    error: (e, __) => Text(
                      'Location unavailable',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                    data: (p) => Text(
                      p.city.isNotEmpty ? p.city : (p.formatted.isNotEmpty ? p.formatted : 'Your area'),
                      style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                weatherAsync.when(
                  loading: () => Text(
                    '—°',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  error: (e, __) => Text(
                    '—°',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  data: (wx) => Text(
                    '${wx.temperature.toStringAsFixed(0)}°',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                weatherAsync.when(
                  loading: () => Text(
                    'Humidity',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                  error: (e, __) => Text(
                    'Humidity',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                  data: (wx) => Text(
                    wx.description.isNotEmpty ? _capitalize(wx.description) : 'Humidity',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                ),
                const SizedBox(height: 6),
                weatherAsync.when(
                  loading: () => Text(
                    '—%',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  error: (e, __) => Text(
                    '—%',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  data: (wx) => Text(
                    '${wx.humidity}%',
                    style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildActionButtons() {
    return Consumer(builder: (context, ref, _) {
      final devices = ref.watch(allDevicesProvider);
      final lightsOn = devices
          .where((d) => d.isOn && (d.type == domain.DeviceType.bulb || d.type == domain.DeviceType.lamp))
          .length;
      final lampsOn = devices.where((d) => d.isOn && d.type == domain.DeviceType.lamp).length;
      final fansOn = devices.where((d) => d.isOn && d.type == domain.DeviceType.fan).length;

      String onLabel(int n) => '$n on';

      return SizedBox(
        height: 90,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildActionButton(
              icon: Icons.wb_incandescent_outlined,
              iconColor: const Color(0xFFFFC861),
              title: 'Lights',
              subtitle: onLabel(lightsOn),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.lightbulb_outline,
              iconColor: const Color(0xFFFF9066),
              title: 'Lamps',
              subtitle: onLabel(lampsOn),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.air,
              iconColor: const Color(0xFF66D4FF),
              title: 'Fans',
              subtitle: onLabel(fansOn),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final colors = _ScreenColors.of(context);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: colors.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesHeader() {
    final colors = _ScreenColors.of(context);
    return Consumer(builder: (context, ref, _) {
      final allDevices = ref.watch(allDevicesProvider);
      final activeCount = allDevices.where((d) => d.isOn).length;
      return Row(
        children: [
          Text(
            'Active Devices',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$activeCount',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDevicesGrid() {
    String _imageFor(domain.DeviceType t) {
      switch (t) {
        case domain.DeviceType.bulb:
          return 'images/bulb.png';
        case domain.DeviceType.lamp:
          return 'images/lamp.png';
        case domain.DeviceType.fan:
          return 'images/fan.png';
      }
    }

    return Consumer(builder: (context, ref, _) {
      final roomsAsync = ref.watch(roomsControllerProvider);
      final rooms = roomsAsync.value ?? [];
      final roomNameById = {for (final r in rooms) r.id: r.name};

      final allDevices = ref.watch(allDevicesProvider);
      final activeDevices = allDevices.where((d) => d.isOn).toList();

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.88,
          crossAxisSpacing: 16,
          mainAxisSpacing: 18,
        ),
        itemCount: activeDevices.length,
        itemBuilder: (context, index) {
          final device = activeDevices[index];
          return _buildDeviceCard(
            name: device.name,
            location: roomNameById[device.roomId] ?? 'Unknown',
            imagePath: _imageFor(device.type),
            isOn: device.isOn,
            onToggle: (value) async {
              await ref.read(devicesControllerProvider(device.roomId).notifier)
                  .toggleDevice(device.id, value);
            },
          );
        },
      );
    });
  }

  Widget _buildDeviceCard({
    required String name,
    required String location,
    required String imagePath,
    required bool isOn,
    required ValueChanged<bool> onToggle,
  }) {
    final colors = _ScreenColors.of(context);
    return PhysicalModel(
      color: colors.surfacePrimary,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      shadowColor: colors.shadowCard.first.color,
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: colors.shadowCard,
          ),
          child: Stack(
            children: [
              // Circular icon positioned at top-left corner (75% visible)
              Positioned(
                left: -12,
                top: -12,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.statusInfo.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      imagePath,
                      width: 45,
                      height: 45,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Toggle Switch at top-right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: isOn,
                            onChanged: onToggle,
                            activeColor: colors.textInverse,
                            activeTrackColor: colors.controlActive,
                            inactiveThumbColor: colors.textInverse,
                            inactiveTrackColor: colors.controlTrack,
                            trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Device Name
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Location
                    Text(
                      location,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.2,
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
  }
}

class DeviceData {
  final String name;
  final String location;
  final String imagePath;
  final bool isOn;

  DeviceData(this.name, this.location, this.imagePath, this.isOn);
}
