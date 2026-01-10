import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../geofencing/models/safe_zone_model.dart';
import '../geofencing/providers/safe_zone_data_provider.dart';
import '../geofencing/services/geofencing_service.dart';
import '../geofencing/services/geocoding_service.dart';

class AddSafeZoneScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final SafeZoneModel? existingZone;

  const AddSafeZoneScreen({
    super.key,
    this.isEditing = false,
    this.existingZone,
  });

  @override
  ConsumerState<AddSafeZoneScreen> createState() => _AddSafeZoneScreenState();
}

class _AddSafeZoneScreenState extends ConsumerState<AddSafeZoneScreen> {
  late double _radius;
  late TextEditingController _nameController;
  SafeZoneType _selectedType = SafeZoneType.home;
  String _mapMode = 'street'; // street, satellite, minimal
  
  // Location state
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  String? _locationError;

  // Alert settings
  bool _alertOnEntry = false;
  bool _alertOnExit = true;

  // Google Maps
  GoogleMapController? _mapController;
  String? _addressText;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingZone != null) {
      // Editing existing zone
      _radius = widget.existingZone!.radiusMeters;
      _nameController = TextEditingController(text: widget.existingZone!.name);
      _selectedType = widget.existingZone!.type;
      _latitude = widget.existingZone!.latitude;
      _longitude = widget.existingZone!.longitude;
      _alertOnEntry = widget.existingZone!.alertOnEntry;
      _alertOnExit = widget.existingZone!.alertOnExit;
      _isLoadingLocation = false;
    } else {
      // New zone - get current location
      _radius = 200.0;
      _nameController = TextEditingController();
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final position = await GeofencingService.instance.getCurrentLocation();
      
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLoadingLocation = false;
        });
        
        // Fetch address for this location
        _fetchAddress(position.latitude, position.longitude);
      } else {
        setState(() {
          _locationError = 'Could not get location. Please check permissions.';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Location error: $e';
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    if (!mounted) return;
    
    setState(() => _isLoadingAddress = true);
    
    try {
      final result = await GeocodingService.instance.reverseGeocode(
        latitude: lat,
        longitude: lng,
      );
      
      if (mounted) {
        setState(() {
          _addressText = result.success ? result.shortAddress : null;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressText = null;
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
    
    // Fetch address for new location
    _fetchAddress(position.latitude, position.longitude);
    
    // Animate to new position
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
  }

  void _onMarkerDrag(LatLng position) {
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
    
    // Fetch address for new location
    _fetchAddress(position.latitude, position.longitude);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF5F5F7))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          color: Color(0xFF0F172A),
                          size: 24,
                        ),
                      ),
                    ),
                    Text(
                      widget.isEditing ? 'Modify Place' : 'Set Safe Place',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 56), // Spacer to balance the close button
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 192), // Bottom padding for fixed button
                  children: [
                    // Map Container
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40), // 2.5rem
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Stack(
                          children: [
                            // Google Map
                            if (_isLoadingLocation)
                              Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Center(
                                  child: CupertinoActivityIndicator(radius: 20),
                                ),
                              )
                            else if (_locationError != null)
                              Container(
                                color: const Color(0xFFE2E8F0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.exclamationmark_triangle, color: Color(0xFFDC2626), size: 32),
                                      const SizedBox(height: 12),
                                      Text('Location Error', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: _getCurrentLocation,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text('Retry', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              _buildInteractiveMap(),

                            // Map Mode Toggle
                            Positioned(
                              bottom: 24,
                              left: 24,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_mapMode == 'street') _mapMode = 'satellite';
                                    else _mapMode = 'street';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                      Icon(
                                        _mapMode == 'satellite' ? CupertinoIcons.globe : CupertinoIcons.map,
                                        size: 20,
                                        color: const Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _mapMode == 'street' ? 'STANDARD' : 'SATELLITE',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF475569),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Tap to move badge
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'TAP OR DRAG TO MOVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            // Recenter button
                            Positioned(
                              bottom: 24,
                              right: 24,
                              child: GestureDetector(
                                onTap: _getCurrentLocation,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.location_fill,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Address display
                    if (_addressText != null || _isLoadingAddress) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.location_solid,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _isLoadingAddress
                                  ? Text(
                                      'Looking up address...',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF94A3B8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : Text(
                                      _addressText ?? 'Unknown location',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // Zone Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZONE SIZE',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF64748B),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Safe coverage area',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_radius.toInt()}m',
                          style: GoogleFonts.inter(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                            letterSpacing: -2.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(36), // 2.25rem
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: CupertinoSlider(
                        value: _radius,
                        min: 100,
                        max: 1000,
                        divisions: 45,
                        activeColor: const Color(0xFF059669),
                        thumbColor: Colors.white,
                        onChanged: (value) {
                          setState(() => _radius = value);
                        },
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Location Name Input
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'LOCATION NAME',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. My Apartment',
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(32),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Identify Place
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'IDENTIFY PLACE',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: SafeZoneType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 110,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF475569) : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  type.icon,
                                  color: isSelected ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                  size: 24,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  type.name.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (widget.isEditing) ...[
                      const SizedBox(height: 40),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFF5F5F7))),
                        ),
                        padding: const EdgeInsets.only(top: 40),
                        child: GestureDetector(
                          onTap: () => _confirmDelete(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.trash,
                                  color: Color(0xFFDC2626),
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Remove this place',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Alert Settings Section
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ALERT SETTINGS',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAlertToggle(
                      title: 'Alert on Exit',
                      subtitle: 'Notify caregivers when leaving this zone',
                      value: _alertOnExit,
                      onChanged: (v) => setState(() => _alertOnExit = v),
                    ),
                    const SizedBox(height: 12),
                    _buildAlertToggle(
                      title: 'Alert on Entry',
                      subtitle: 'Notify caregivers when entering this zone',
                      value: _alertOnEntry,
                      onChanged: (v) => setState(() => _alertOnEntry = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Fixed Bottom Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF5F5F7))),
              ),
              child: GestureDetector(
                onTap: _canSave ? _saveZone : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: _canSave 
                        ? const Color(0xFF0F172A) 
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _canSave ? [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ] : [],
                  ),
                  child: _isSaving
                      ? const Center(
                          child: CupertinoActivityIndicator(color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.check_mark,
                              color: _canSave ? Colors.white : const Color(0xFF94A3B8),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              widget.isEditing ? 'Update Zone' : 'Save Settings',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _canSave ? Colors.white : const Color(0xFF94A3B8),
                              ),
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

  bool get _canSave => 
      _nameController.text.isNotEmpty && 
      _latitude != null && 
      _longitude != null &&
      !_isSaving;

  Widget _buildInteractiveMap() {
    if (_latitude == null || _longitude == null) {
      return Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(
          child: CupertinoActivityIndicator(radius: 20),
        ),
      );
    }

    final center = LatLng(_latitude!, _longitude!);
    
    // Build circle for zone preview
    final circles = <Circle>{
      Circle(
        circleId: const CircleId('zone_preview'),
        center: center,
        radius: _radius,
        fillColor: Color(_selectedType.colorValue).withOpacity(0.2),
        strokeColor: Color(_selectedType.colorValue),
        strokeWidth: 3,
      ),
    };

    // Build draggable marker
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('zone_center'),
        position: center,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(_selectedType)),
        onDragEnd: _onMarkerDrag,
      ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: _getZoomForRadius(_radius),
      ),
      mapType: _mapMode == 'satellite' ? MapType.satellite : MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      circles: circles,
      markers: markers,
      onMapCreated: (controller) {
        _mapController = controller;
      },
      onTap: _onMapTap,
      onCameraMove: (position) {
        // Update zoom-based radius visualization could go here
      },
    );
  }

  double _getZoomForRadius(double radius) {
    if (radius > 800) return 13.0;
    if (radius > 500) return 14.0;
    if (radius > 300) return 15.0;
    if (radius > 150) return 16.0;
    return 17.0;
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

  Widget _buildAlertToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Future<void> _saveZone() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(safeZoneNotifierProvider.notifier);

      if (widget.isEditing && widget.existingZone != null) {
        // Update existing zone
        final updated = widget.existingZone!.copyWith(
          name: _nameController.text.trim(),
          radiusMeters: _radius,
          type: _selectedType,
          latitude: _latitude,
          longitude: _longitude,
          alertOnEntry: _alertOnEntry,
          alertOnExit: _alertOnExit,
        );
        await notifier.updateZone(updated);
      } else {
        // Create new zone
        await notifier.createZone(
          name: _nameController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          radiusMeters: _radius,
          type: _selectedType,
          alertOnEntry: _alertOnEntry,
          alertOnExit: _alertOnExit,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Failed to save zone: $e');
      }
    }
  }

  void _confirmDelete() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Safe Zone?'),
        content: Text('Are you sure you want to delete "${widget.existingZone?.name}"?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.existingZone != null) {
                await ref.read(safeZoneNotifierProvider.notifier)
                    .deleteZone(widget.existingZone!.id);
                if (mounted) {
                  Navigator.pop(context, true);
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;

  GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}
