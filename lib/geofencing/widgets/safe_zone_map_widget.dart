/// SafeZoneMapWidget - Reusable Google Maps widget for displaying safe zones.
///
/// Supports two modes:
/// - View Mode: Display all zones with circles, current location
/// - Edit Mode: Single zone with draggable marker, adjustable radius
library;

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../geofencing/models/safe_zone_model.dart';

/// Map display mode
enum SafeZoneMapMode {
  /// View all zones (SafeZonesScreen)
  view,
  /// Edit/create a single zone (AddSafeZoneScreen)
  edit,
}

/// Callback when user taps on the map (edit mode)
typedef OnLocationSelected = void Function(double latitude, double longitude);

/// Reusable Google Maps widget for safe zones
class SafeZoneMapWidget extends StatefulWidget {
  /// Map display mode
  final SafeZoneMapMode mode;

  /// List of zones to display (view mode)
  final List<SafeZoneModel>? zones;

  /// Current user location
  final Position? currentLocation;

  /// Selected location for new/editing zone (edit mode)
  final double? selectedLatitude;
  final double? selectedLongitude;

  /// Radius for the selected zone (edit mode)
  final double? selectedRadius;

  /// Zone type for the selected zone (edit mode) - for marker color
  final SafeZoneType? selectedType;

  /// Callback when user taps on map (edit mode)
  final OnLocationSelected? onLocationSelected;

  /// Whether to show satellite view
  final bool satelliteView;

  /// Whether the map is loading
  final bool isLoading;

  /// Error message to display
  final String? errorMessage;

  const SafeZoneMapWidget({
    super.key,
    required this.mode,
    this.zones,
    this.currentLocation,
    this.selectedLatitude,
    this.selectedLongitude,
    this.selectedRadius,
    this.selectedType,
    this.onLocationSelected,
    this.satelliteView = false,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<SafeZoneMapWidget> createState() => _SafeZoneMapWidgetState();
}

class _SafeZoneMapWidgetState extends State<SafeZoneMapWidget> {
  GoogleMapController? _mapController;
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};

  // Default location (will be overridden by actual location)
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194); // San Francisco

  @override
  void initState() {
    super.initState();
    _updateMapElements();
  }

  @override
  void didUpdateWidget(SafeZoneMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update circles and markers when data changes
    if (oldWidget.zones != widget.zones ||
        oldWidget.selectedLatitude != widget.selectedLatitude ||
        oldWidget.selectedLongitude != widget.selectedLongitude ||
        oldWidget.selectedRadius != widget.selectedRadius ||
        oldWidget.selectedType != widget.selectedType ||
        oldWidget.currentLocation != widget.currentLocation) {
      _updateMapElements();
    }
  }

  void _updateMapElements() {
    if (widget.mode == SafeZoneMapMode.view) {
      _buildViewModeElements();
    } else {
      _buildEditModeElements();
    }
  }

  void _buildViewModeElements() {
    final circles = <Circle>{};
    final markers = <Marker>{};

    // Add circles for each zone
    if (widget.zones != null) {
      for (final zone in widget.zones!) {
        circles.add(Circle(
          circleId: CircleId(zone.id),
          center: LatLng(zone.latitude, zone.longitude),
          radius: zone.radiusMeters,
          fillColor: Color(zone.type.colorValue).withOpacity(0.15),
          strokeColor: Color(zone.type.colorValue).withOpacity(0.6),
          strokeWidth: 2,
        ));

        // Add marker at zone center
        markers.add(Marker(
          markerId: MarkerId(zone.id),
          position: LatLng(zone.latitude, zone.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(zone.type),
          ),
          infoWindow: InfoWindow(
            title: zone.name,
            snippet: '${zone.radiusMeters.toInt()}m radius',
          ),
        ));
      }
    }

    // Add current location marker
    if (widget.currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You are here'),
      ));
    }

    setState(() {
      _circles = circles;
      _markers = markers;
    });
  }

  void _buildEditModeElements() {
    final circles = <Circle>{};
    final markers = <Marker>{};

    // Add the zone being edited/created
    if (widget.selectedLatitude != null && widget.selectedLongitude != null) {
      final center = LatLng(widget.selectedLatitude!, widget.selectedLongitude!);
      final radius = widget.selectedRadius ?? 200.0;
      final type = widget.selectedType ?? SafeZoneType.home;

      circles.add(Circle(
        circleId: const CircleId('edit_zone'),
        center: center,
        radius: radius,
        fillColor: Color(type.colorValue).withOpacity(0.2),
        strokeColor: Color(type.colorValue),
        strokeWidth: 3,
      ));

      markers.add(Marker(
        markerId: const MarkerId('edit_marker'),
        position: center,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(type)),
        onDragEnd: (newPosition) {
          widget.onLocationSelected?.call(
            newPosition.latitude,
            newPosition.longitude,
          );
        },
      ));
    }

    setState(() {
      _circles = circles;
      _markers = markers;
    });
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

  LatLng _getInitialCameraPosition() {
    // Priority: selected location > current location > first zone > default
    if (widget.selectedLatitude != null && widget.selectedLongitude != null) {
      return LatLng(widget.selectedLatitude!, widget.selectedLongitude!);
    }
    if (widget.currentLocation != null) {
      return LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
    }
    if (widget.zones != null && widget.zones!.isNotEmpty) {
      final firstZone = widget.zones!.first;
      return LatLng(firstZone.latitude, firstZone.longitude);
    }
    return _defaultLocation;
  }

  double _getInitialZoom() {
    if (widget.mode == SafeZoneMapMode.edit) {
      // Zoom based on radius
      final radius = widget.selectedRadius ?? 200.0;
      if (radius > 800) return 13.0;
      if (radius > 400) return 14.0;
      if (radius > 200) return 15.0;
      return 16.0;
    }
    // View mode - zoom to fit all zones
    return 14.0;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBoundsIfNeeded();
  }

  void _fitBoundsIfNeeded() {
    if (widget.mode != SafeZoneMapMode.view) return;
    if (widget.zones == null || widget.zones!.isEmpty) return;
    if (_mapController == null) return;

    // Build bounds that include all zones
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (final zone in widget.zones!) {
      // Approximate degrees for radius
      final radiusDegrees = zone.radiusMeters / 111320;
      
      if (zone.latitude - radiusDegrees < minLat) minLat = zone.latitude - radiusDegrees;
      if (zone.latitude + radiusDegrees > maxLat) maxLat = zone.latitude + radiusDegrees;
      if (zone.longitude - radiusDegrees < minLng) minLng = zone.longitude - radiusDegrees;
      if (zone.longitude + radiusDegrees > maxLng) maxLng = zone.longitude + radiusDegrees;
    }

    // Include current location
    if (widget.currentLocation != null) {
      if (widget.currentLocation!.latitude < minLat) minLat = widget.currentLocation!.latitude;
      if (widget.currentLocation!.latitude > maxLat) maxLat = widget.currentLocation!.latitude;
      if (widget.currentLocation!.longitude < minLng) minLng = widget.currentLocation!.longitude;
      if (widget.currentLocation!.longitude > maxLng) maxLng = widget.currentLocation!.longitude;
    }

    if (minLat.isFinite && maxLat.isFinite && minLng.isFinite && maxLng.isFinite) {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      });
    }
  }

  void _onMapTap(LatLng position) {
    if (widget.mode == SafeZoneMapMode.edit) {
      widget.onLocationSelected?.call(position.latitude, position.longitude);
    }
  }

  Future<void> _animateToCurrentLocation() async {
    if (widget.currentLocation == null || _mapController == null) return;
    
    await _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (widget.isLoading) {
      return _buildPlaceholder(
        child: const CupertinoActivityIndicator(radius: 20),
      );
    }

    // Show error state
    if (widget.errorMessage != null) {
      return _buildPlaceholder(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: Color(0xFFDC2626),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              widget.errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _getInitialCameraPosition(),
        zoom: _getInitialZoom(),
      ),
      mapType: widget.satelliteView ? MapType.satellite : MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      circles: _circles,
      markers: _markers,
      onMapCreated: _onMapCreated,
      onTap: _onMapTap,
    );
  }

  Widget _buildPlaceholder({required Widget child}) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Center(child: child),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

/// Extension to add a location button overlay
class SafeZoneMapWithControls extends StatelessWidget {
  final SafeZoneMapWidget mapWidget;
  final VoidCallback? onMyLocationPressed;
  final VoidCallback? onMapTypeToggle;
  final bool showMapTypeToggle;
  final String? mapTypeLabel;

  const SafeZoneMapWithControls({
    super.key,
    required this.mapWidget,
    this.onMyLocationPressed,
    this.onMapTypeToggle,
    this.showMapTypeToggle = true,
    this.mapTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        mapWidget,
        
        // My Location Button
        if (onMyLocationPressed != null)
          Positioned(
            top: 16,
            right: 16,
            child: _buildControlButton(
              icon: CupertinoIcons.location_fill,
              onTap: onMyLocationPressed!,
            ),
          ),

        // Map Type Toggle
        if (showMapTypeToggle && onMapTypeToggle != null)
          Positioned(
            bottom: 16,
            left: 16,
            child: GestureDetector(
              onTap: onMapTypeToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.map,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mapTypeLabel ?? 'Map',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
