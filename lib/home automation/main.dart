import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/data/home_automation_hive_bridge.dart';
import 'src/data/local_hive_service.dart';
// Host app will import these directly where needed.
import 'src/logic/providers/room_providers.dart';
import 'src/logic/providers/device_providers.dart';
import 'src/logic/providers/weather_location_providers.dart';
import 'src/data/models/device_model.dart' as domain;
import 'navigation/drawer_wrapper.dart';

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

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration:  BoxDecoration(
          
          color: Colors.white
          
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Fixed Header
            Container(
             height: 320,
             decoration: BoxDecoration(
               
               gradient: LinearGradient(colors:  [
                  Color(0xFF3D2E6B),
            Color(0xFF3D2E6B),
               ]),
               borderRadius: BorderRadius.only(
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleDrawer,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _menuAnimationController,
              color: Colors.white.withOpacity(0.9),
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
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
            image: const DecorationImage(
              image: NetworkImage(
                'https://i.pravatar.cc/150?img=47',
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
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Savannah Nguyen',
                style: TextStyle(
                  color: Colors.white,
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
    return Consumer(builder: (context, ref, _) {
      final weatherAsync = ref.watch(currentWeatherProvider);
      final placeAsync = ref.watch(reverseGeocodeProvider);
      return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D2E6B),
            Color(0xFF252045),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1438).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF1A1438).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
        child: Row(
          children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
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
                          color: Colors.white.withOpacity(0.3),
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
                    loading: () => const Text(
                      'Locating…',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                    error: (e, __) => const Text(
                      'Location unavailable',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                    data: (p) => Text(
                      p.city.isNotEmpty ? p.city : (p.formatted.isNotEmpty ? p.formatted : 'Your area'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                weatherAsync.when(
                  loading: () => const Text(
                    '—°',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  error: (e, __) => const Text(
                    '—°',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  data: (wx) => Text(
                    '${wx.temperature.toStringAsFixed(0)}°',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                weatherAsync.when(
                  loading: () => const Text(
                    'Humidity',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                  error: (e, __) => const Text(
                    'Humidity',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                  data: (wx) => Text(
                    wx.description.isNotEmpty ? _capitalize(wx.description) : 'Humidity',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                  ),
                ),
                const SizedBox(height: 6),
                weatherAsync.when(
                  loading: () => const Text(
                    '—%',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  error: (e, __) => const Text(
                    '—%',
                    style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
                  ),
                  data: (wx) => Text(
                    '${wx.humidity}%',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.0, letterSpacing: -0.5),
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
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
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
                  style: const TextStyle(
                    color: Color(0xFF1A1438),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF1A1438).withOpacity(0.5),
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
    return Consumer(builder: (context, ref, _) {
      final allDevices = ref.watch(allDevicesProvider);
      final activeCount = allDevices.where((d) => d.isOn).length;
      return Row(
        children: [
          const Text(
            'Active Devices',
            style: TextStyle(
              color: Color(0xFF1A1438),
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1438).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$activeCount',
              style: TextStyle(
                color: const Color(0xFF1A1438).withOpacity(0.6),
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
    return PhysicalModel(
      color: Colors.white,
  elevation: 8,
  borderRadius: BorderRadius.circular(20),
  shadowColor: Colors.black.withOpacity(0.3),
  clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
                spreadRadius: 1,
              ),
            ],
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
                    color: const Color.fromARGB(255, 150, 150, 191),
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
                            activeColor: Colors.white,
                            activeTrackColor: const Color(0xFF4D7CFE),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFE0E0E0),
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
                      style: const TextStyle(
                        color: Color(0xFF2D2D2D),
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
                        color: const Color(0xFF9E9E9E),
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
