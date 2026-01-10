/// Home Automation Dashboard extracted from next_screen.dart
/// Provides the automation page content (header, status overview, rooms,
/// devices, energy usage, automation cards) as a standalone reusable widget.
///
/// Migration Notes:
/// - Original private builders (_buildAutomationHeader, _buildQuickStatusOverview, etc.)
///   moved here as private methods inside this StatelessWidget.
/// - The parent screen (`NextScreen`) now only supplies the top bar and wraps this
///   dashboard inside an `Expanded`.
/// - This widget expects an `isDarkMode` boolean for theme adaptation.
/// - Navigation to `AllRoomsScreen` and `RoomDetailsScreen` preserved.
/// - Haptic feedback + minimal debug prints retained.

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'all_rooms_screen.dart';
import 'room_details_screen.dart';
// Health Stability Score integration
import 'stability_score/stability_score.dart';

/// Monochrome emotional palette (Chunk 1)
/// Focused, calm, minimal – with gentle optional warmth tints.
class HomeAutomationPalette {
  // Core tones
  static const Color base = Color(0xFFF9FAFB); // soft white-gray background
  static const Color accent = Color(0xFFE5E7EB); // cards / bubbles / surfaces
  static const Color contrast = Color(0xFF1C1C1E); // deep neutral for text
  static const Color highlight = Color(0xFF8E8E93); // inactive / subtle icons

  // Optional comforting warmth (choose one in future refinements)
  static const Color warmBlueTint = Color(0xFFE9F2F8); // faint muted blue
  static const Color warmSandTint = Color(0xFFF4EDE3); // soft sand beige

  // Helpers --------------------------------------------------------------
  static BoxDecoration cardSurface({bool elevated = false, bool blue = false, bool sand = false}) {
    final Color baseColor = accent;
    final overlay = blue
        ? warmBlueTint
        : sand
            ? warmSandTint
            : baseColor;
    return BoxDecoration(
      color: overlay,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.85), width: 1),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: contrast.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ]
          : [],
    );
  }

  static TextStyle titleStyle({bool subtle = false}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: subtle ? highlight : contrast,
      );
  static TextStyle bodyStyle({double size = 13, bool dim = false}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: dim ? highlight : contrast,
      );
}

class HomeAutomationDashboard extends StatelessWidget {
  final bool isDarkMode;
  const HomeAutomationDashboard({super.key, required this.isDarkMode});

  // Typography system (Chunk 2) aligned with iOS HIG style guidance.
  // We use SF Pro style assumptions; if a custom font is provided via Theme,
  // TextStyles will inherit it. Centralized for consistent hierarchy.
  _Typography get _typo => _Typography(isDarkMode);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildAutomationHeader(context),
              const SizedBox(height: 24),
              _buildQuickStatusOverview(),
              const SizedBox(height: 28),
              _buildRoomSection(context),
              const SizedBox(height: 28),
              _buildDeviceSection(),
              const SizedBox(height: 28),
              _buildEnergyUsageSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        // Ambient subtle noise overlay to add organic texture
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: _SubtleNoiseOverlay(
              isDark: isDarkMode,
              opacity: isDarkMode ? 0.02 : 0.025,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildAutomationHeader(BuildContext context) {
    final baseGlass = (isDarkMode ? Colors.black : Colors.white).withOpacity(0.08);
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);
    final bottomTint = isDarkMode
        ? const Color(0x33000000) // subtle dark tint
        : const Color(0xFFF2F2F2).withOpacity(0.75); // faint light diffusion

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: baseGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.16 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Faint gradient overlay: top transparent -> bottom tinted
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          bottomTint,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  // Avatar with HSS badge below
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingStatusAvatar(
                        imageAsset: 'images/male.jpg',
                        isDarkMode: isDarkMode,
                        ringColor: const Color(0xFF10B981), // calm green pulse
                        size: 50,
                      ),
                      const SizedBox(height: 6),
                      // HSS Badge
                      const HSSBadge(
                        size: HSSBadgeSize.small,
                        showLabel: true,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alex', style: _typo.header(isDarkMode)),
                        Text('Good Morning!', style: _typo.subtext13(isDarkMode)),
                      ],
                    ),
                  ),
                  // Minimal monochrome icons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassIconButton(
                        icon: CupertinoIcons.bell,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      _GlassIconButton(
                        icon: CupertinoIcons.slider_horizontal_3,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Status Overview
  // ---------------------------------------------------------------------------
  Widget _buildQuickStatusOverview() {
    final statusItems = [
      {
        'icon': CupertinoIcons.thermometer,
        'label': 'Temperature',
        'value': '72°F',
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': CupertinoIcons.lightbulb,
        'label': 'Light',
        'value': '4 On',
        'color': const Color(0xFFEAB308),
      },
      {
        'icon': CupertinoIcons.bolt,
        'label': 'Energy',
        'value': 'Low',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': CupertinoIcons.shield,
        'label': 'Security',
        'value': 'Alarmed',
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Row(
      children: statusItems.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(16),
            decoration: isDarkMode
                ? BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  )
                : HomeAutomationPalette.cardSurface(elevated: true),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: item['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'] as String,
                  style: _typo.subtext13(isDarkMode),
                ),
                const SizedBox(height: 2),
                Text(
                  item['value'] as String,
                  style: _typo.body16(isDarkMode, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Rooms
  // ---------------------------------------------------------------------------
  Widget _buildRoomSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Room',
              style: _typo.sectionTitle(isDarkMode),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        AllRoomsScreen(isDarkMode: isDarkMode),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;
                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
                debugPrint('Navigate to all rooms');
              },
              child: Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildRoomCard(
              context,
              roomId: 'living_room',
              icon: CupertinoIcons.house,
              label: 'Living Room',
              devices: '5 Devices',
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 12),
            _buildRoomCard(
              context,
              roomId: 'kitchen',
              icon: CupertinoIcons.scissors,
              label: 'Kitchen',
              devices: '3 Devices',
              color: const Color(0xFFEAB308),
            ),
            const SizedBox(width: 12),
            _buildRoomCard(
              context,
              roomId: 'bed_room',
              icon: CupertinoIcons.bed_double,
              label: 'Bed Room',
              devices: '3 Devices',
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomCard(
    BuildContext context, {
    required String roomId,
    required IconData icon,
    required String label,
    required String devices,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RoomDetailsScreen(
                roomId: roomId,
                roomName: label,
                roomIcon: icon,
                roomColor: color,
                isDarkMode: isDarkMode,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
          debugPrint('Navigate to room: $label');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isDarkMode
              ? BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                )
              : HomeAutomationPalette.cardSurface(elevated: true),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: _typo.body16(isDarkMode, weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                devices,
                style: _typo.subtext13(isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------
  Widget _buildDeviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Device',
              style: _typo.sectionTitle(isDarkMode),
            ),
            Text(
              'Manage',
              style: _typo.link14,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDeviceItem(
          icon: CupertinoIcons.lightbulb,
          name: 'Living Room Light',
          status: 'On • 50% Brightness',
          isOn: true,
          color: const Color(0xFFEAB308),
        ),
        const SizedBox(height: 12),
        _buildDeviceItem(
          icon: CupertinoIcons.thermometer,
          name: 'Thermostat',
          status: 'Cooling • Auto Mode',
          isOn: true,
          color: const Color(0xFF3B82F6),
          showTemperature: true,
          temperature: '72°F',
        ),
        const SizedBox(height: 12),
        _buildDeviceItem(
          icon: CupertinoIcons.wind,
          name: 'Fan',
          status: 'On • 60% Speed',
          isOn: true,
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildDeviceItem({
    required IconData icon,
    required String name,
    required String status,
    required bool isOn,
    required Color color,
    bool showTemperature = false,
    String? temperature,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isDarkMode
          ? BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            )
          : HomeAutomationPalette.cardSurface(elevated: true),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _typo.body16(isDarkMode, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: _typo.subtext13(isDarkMode),
                ),
              ],
            ),
          ),
          if (showTemperature && temperature != null) ...[
            Text(
              temperature,
              style: _typo.body16(isDarkMode, weight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
          ],
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              debugPrint('Toggle device: $name');
            },
            child: Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: isOn
                    ? const Color(0xFF3B82F6)
                    : isDarkMode
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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

  // ---------------------------------------------------------------------------
  // Energy Usage
  // ---------------------------------------------------------------------------
  Widget _buildEnergyUsageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: isDarkMode
          ? BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : HomeAutomationPalette.cardSurface(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Usage',
                style: _typo.sectionTitle(isDarkMode),
              ),
              const Text(
                'Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.1,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Usage",
                    style: _typo.subtext13(isDarkMode),
                  ),
                  Text(
                    'Apr 22, 2025',
                    style: _typo.subtext13(isDarkMode, opacity: isDarkMode ? 0.5 : 0.8),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '12.4 kWh',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      letterSpacing: -0.2,
                      color: isDarkMode ? Colors.white : HomeAutomationPalette.contrast,
                    ),
                  ),
                  Text(
                    '-5% vs yesterday',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      letterSpacing: -0.1,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : HomeAutomationPalette.accent.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: 0.6,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted avatar with subtle pulsing status ring (accessibility-friendly)
class _PulsingStatusAvatar extends StatefulWidget {
  final String imageAsset;
  final bool isDarkMode;
  final Color ringColor;
  final double size;
  const _PulsingStatusAvatar({
    required this.imageAsset,
    required this.isDarkMode,
    required this.ringColor,
    this.size = 50,
  });

  @override
  State<_PulsingStatusAvatar> createState() => _PulsingStatusAvatarState();
}

class _PulsingStatusAvatarState extends State<_PulsingStatusAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ringSize = widget.size + 12; // outer pulse extent
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated expanding subtle ring
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value; // 0..1
                  final scale = 0.85 + (t * 0.35); // gentle expansion
                  final opacity = (1 - t).clamp(0.0, 1.0) * 0.35; // fade out
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.ringColor.withOpacity(opacity),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Static ring + avatar
          Container(
            width: widget.size + 6,
            height: widget.size + 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  widget.ringColor.withOpacity(0.55),
                  widget.ringColor.withOpacity(0.15),
                ],
              ),
              border: Border.all(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.10)
                    : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Center(
              child: ClipOval(
                child: Image.asset(
                  widget.imageAsset,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Icon(
                    CupertinoIcons.person_fill,
                    size: widget.size * 0.55,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-usable glassy icon button for header actions
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

/// Subtle noise overlay to add organic texture at very low opacity
class _SubtleNoiseOverlay extends StatelessWidget {
  final double opacity; // suggested 0.02–0.03
  final bool isDark;
  const _SubtleNoiseOverlay({required this.opacity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NoisePainter(opacity: opacity, isDark: isDark),
      willChange: false,
      isComplex: false,
    );
  }
}

class _NoisePainter extends CustomPainter {
  final double opacity;
  final bool isDark;
  _NoisePainter({required this.opacity, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42); // deterministic subtle pattern
    final paint = Paint()
      ..color = (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A))
          .withOpacity(opacity)
      ..style = PaintingStyle.fill;

    // Sparse dots in a loose grid for organic grain
    const step = 6.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        if (rnd.nextDouble() < 0.22) {
          // jitter position slightly
          final jx = x + (rnd.nextDouble() - 0.5) * 2.0;
          final jy = y + (rnd.nextDouble() - 0.5) * 2.0;
          final r = 0.5 + rnd.nextDouble() * 0.6; // tiny dot radius
          canvas.drawCircle(Offset(jx, jy), r, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Helper: frosted modal sheet with system blur + light noise overlay
Future<T?> showFrostedSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isDark = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _SubtleNoiseOverlay(opacity: 0.02, isDark: isDark),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Lightweight typography helper encapsulating hierarchy.
class _Typography {
  final bool isDark;
  _Typography(this.isDark);

  Color get _base => isDark ? Colors.white : HomeAutomationPalette.contrast;
  Color get _sub => isDark ? Colors.white.withOpacity(0.6) : HomeAutomationPalette.highlight.withOpacity(0.75);

  TextStyle header(bool dark) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.3,
        color: _base,
      );

  TextStyle sectionTitle(bool dark) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.25,
        color: _base,
      );

  TextStyle body16(bool dark, {FontWeight weight = FontWeight.w500}) => TextStyle(
        fontSize: 16,
        fontWeight: weight,
        height: 1.35,
        letterSpacing: -0.2,
        color: _base,
      );

  TextStyle subtext13(bool dark, {double? opacity}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: -0.1,
        color: opacity != null ? _sub.withOpacity(opacity) : _sub,
      );

  TextStyle get link14 => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.35,
        letterSpacing: -0.15,
        color: Color(0xFF3B82F6),
      );
}
