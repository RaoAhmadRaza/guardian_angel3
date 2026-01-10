import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'add_safe_zone_screen.dart';
import 'safe_zone_info_screen.dart';
import '../geofencing/models/safe_zone_model.dart';
import '../geofencing/providers/safe_zone_data_provider.dart';

class SafeZonesScreen extends ConsumerStatefulWidget {
  const SafeZonesScreen({super.key});

  @override
  ConsumerState<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends ConsumerState<SafeZonesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  GoogleMapController? _mapController;
  bool _satelliteView = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Initialize geofencing on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGeofencing();
    });
  }

  Future<void> _initializeGeofencing() async {
    final control = ref.read(geofencingControlProvider.notifier);
    final hasPermission = await control.checkPermissions();
    if (hasPermission) {
      await control.startMonitoring();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(safeZonesStreamProvider);
    final safeStatus = ref.watch(currentSafeStatusProvider);
    final activeCount = ref.watch(activeZonesCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildMapHeader(safeStatus),
                    _buildZoneList(zonesAsync, activeCount),
                    const SizedBox(height: 120), // Space for bottom button
                  ],
                ),
              ),
            ],
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
              ),
            ),
          ),
          Text(
            'Safe Zones',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const SafeZoneInfoScreen(),
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.info,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapHeader(SafeZoneStatus safeStatus) {
    final isMonitoring = ref.watch(geofencingControlProvider).isMonitoring;
    final zonesAsync = ref.watch(safeZonesStreamProvider);
    final currentLocationAsync = ref.watch(currentLocationProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40), // 2.5rem approx
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          children: [
            // Google Maps
            _buildGoogleMap(zonesAsync, currentLocationAsync),

            // Top Badges
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isMonitoring 
                            ? const Color(0xFF10B981) // emerald-500
                            : const Color(0xFFF59E0B), // amber-500
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMonitoring ? 'Live Monitoring' : 'Monitoring Paused',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map Type Toggle
            Positioned(
              top: 20,
              right: 60,
              child: GestureDetector(
                onTap: () {
                  setState(() => _satelliteView = !_satelliteView);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _satelliteView ? CupertinoIcons.map : CupertinoIcons.globe,
                    size: 16,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),

            // Recenter Button
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: () async {
                  await ref.read(geofencingControlProvider.notifier).refreshZoneStates();
                  _recenterMap();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.location_fill,
                    size: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),

            // Bottom Info Card
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusBackgroundColor(safeStatus.isSafe),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _getStatusIcon(safeStatus.isSafe),
                        color: _getStatusIconColor(safeStatus.isSafe),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(safeStatus.isSafe),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            safeStatus.message,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (safeStatus.isSafe == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '100%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap(
    AsyncValue<List<SafeZoneModel>> zonesAsync,
    AsyncValue<dynamic> currentLocationAsync,
  ) {
    // Build circles for zones
    final circles = <Circle>{};
    final markers = <Marker>{};
    LatLng? initialPosition;

    zonesAsync.whenData((zones) {
      for (final zone in zones) {
        circles.add(Circle(
          circleId: CircleId(zone.id),
          center: LatLng(zone.latitude, zone.longitude),
          radius: zone.radiusMeters,
          fillColor: Color(zone.type.colorValue).withOpacity(0.15),
          strokeColor: Color(zone.type.colorValue).withOpacity(0.6),
          strokeWidth: 2,
        ));

        markers.add(Marker(
          markerId: MarkerId(zone.id),
          position: LatLng(zone.latitude, zone.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(zone.type),
          ),
          infoWindow: InfoWindow(
            title: zone.name,
            snippet: '${zone.radiusMeters.toInt()}m radius${zone.isCurrentlyInside == true ? ' • Inside' : ''}',
          ),
        ));

        initialPosition ??= LatLng(zone.latitude, zone.longitude);
      }
    });

    currentLocationAsync.whenData((position) {
      if (position != null) {
        initialPosition = LatLng(position.latitude, position.longitude);
      }
    });

    // Default to San Francisco if no location
    initialPosition ??= const LatLng(37.7749, -122.4194);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition!,
        zoom: 14.0,
      ),
      mapType: _satelliteView ? MapType.satellite : MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      circles: circles,
      markers: markers,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapBounds(zonesAsync);
      },
    );
  }

  void _fitMapBounds(AsyncValue<List<SafeZoneModel>> zonesAsync) {
    zonesAsync.whenData((zones) {
      if (zones.isEmpty || _mapController == null) return;

      double minLat = double.infinity;
      double maxLat = double.negativeInfinity;
      double minLng = double.infinity;
      double maxLng = double.negativeInfinity;

      for (final zone in zones) {
        final radiusDegrees = zone.radiusMeters / 111320;
        
        if (zone.latitude - radiusDegrees < minLat) minLat = zone.latitude - radiusDegrees;
        if (zone.latitude + radiusDegrees > maxLat) maxLat = zone.latitude + radiusDegrees;
        if (zone.longitude - radiusDegrees < minLng) minLng = zone.longitude - radiusDegrees;
        if (zone.longitude + radiusDegrees > maxLng) maxLng = zone.longitude + radiusDegrees;
      }

      if (minLat.isFinite && maxLat.isFinite && minLng.isFinite && maxLng.isFinite) {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 60),
          );
        });
      }
    });
  }

  void _recenterMap() async {
    final currentLocation = await ref.read(currentLocationProvider.future);
    if (currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(currentLocation.latitude, currentLocation.longitude),
        ),
      );
    }
  }

  double _getMarkerHue(SafeZoneType type) {
    switch (type) {
      case SafeZoneType.home:
        return BitmapDescriptor.hueBlue;
      case SafeZoneType.work:
        return BitmapDescriptor.hueViolet;
      case SafeZoneType.park:
        return BitmapDescriptor.hueGreen;
      case SafeZoneType.gym:
        return BitmapDescriptor.hueRed;
      case SafeZoneType.school:
        return BitmapDescriptor.hueOrange;
      case SafeZoneType.medical:
        return BitmapDescriptor.hueRose;
      case SafeZoneType.grocery:
        return BitmapDescriptor.hueCyan;
      case SafeZoneType.other:
        return BitmapDescriptor.hueMagenta;
    }
  }

  String _getStatusTitle(bool? isSafe) {
    if (isSafe == true) return 'Currently Safe';
    if (isSafe == false) return 'Outside Safe Zones';
    return 'Status Unknown';
  }

  IconData _getStatusIcon(bool? isSafe) {
    if (isSafe == true) return CupertinoIcons.shield_fill;
    if (isSafe == false) return CupertinoIcons.exclamationmark_triangle_fill;
    return CupertinoIcons.question_circle_fill;
  }

  Color _getStatusBackgroundColor(bool? isSafe) {
    if (isSafe == true) return const Color(0xFFEFF6FF);
    if (isSafe == false) return const Color(0xFFFEF2F2);
    return const Color(0xFFF5F5F7);
  }

  Color _getStatusIconColor(bool? isSafe) {
    if (isSafe == true) return const Color(0xFF2563EB);
    if (isSafe == false) return const Color(0xFFDC2626);
    return const Color(0xFF64748B);
  }

  Widget _buildZoneList(AsyncValue<List<SafeZoneModel>> zonesAsync, int activeCount) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Zones',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '$activeCount Active',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          zonesAsync.when(
            data: (zones) {
              if (zones.isEmpty) {
                return _buildEmptyState();
              }
              return Column(
                children: zones.map((zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildZoneCard(zone),
                )).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CupertinoActivityIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Error loading zones',
                  style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              CupertinoIcons.location_slash,
              color: Color(0xFF64748B),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Safe Zones Yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first safe zone to start monitoring',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(SafeZoneModel zone) {
    return GestureDetector(
      onTap: () => _showZoneOptions(zone),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(zone.type.backgroundColorValue),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                zone.type.icon,
                color: Color(zone.type.colorValue),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          zone.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (zone.isCurrentlyInside == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'INSIDE',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${zone.radiusMeters.toInt()}m radius • ${zone.isActive ? 'Monitoring' : 'Paused'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showZoneOptions(SafeZoneModel zone) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          zone.name,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        message: Text('${zone.radiusMeters.toInt()}m radius'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => AddSafeZoneScreen(
                    isEditing: true,
                    existingZone: zone,
                  ),
                ),
              );
            },
            child: const Text('Edit Zone'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(safeZoneNotifierProvider.notifier).toggleZoneActive(zone.id);
            },
            child: Text(zone.isActive ? 'Pause Monitoring' : 'Resume Monitoring'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteZone(zone);
            },
            child: const Text('Delete Zone'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDeleteZone(SafeZoneModel zone) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Safe Zone?'),
        content: Text('Are you sure you want to delete "${zone.name}"? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(safeZoneNotifierProvider.notifier).deleteZone(zone.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Positioned(
      bottom: 40,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            CupertinoPageRoute(
              builder: (context) => const AddSafeZoneScreen(),
            ),
          );
          
          // Refresh zones if a new one was added
          if (result == true) {
            ref.invalidate(safeZonesStreamProvider);
          }
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.add,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Add New Safe Zone',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    const double gridSize = 40;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
