import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AddSafeZoneScreen extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? zoneData;

  const AddSafeZoneScreen({
    super.key,
    this.isEditing = false,
    this.zoneData,
  });

  @override
  State<AddSafeZoneScreen> createState() => _AddSafeZoneScreenState();
}

class _AddSafeZoneScreenState extends State<AddSafeZoneScreen> {
  late double _radius;
  late TextEditingController _nameController;
  String _selectedType = 'home';
  String _mapMode = 'street'; // street, satellite, minimal

  final Map<String, IconData> _zoneIcons = {
    'home': CupertinoIcons.house_fill,
    'work': CupertinoIcons.briefcase_fill,
    'park': CupertinoIcons.tree,
    'gym': CupertinoIcons.sportscourt_fill,
    'school': CupertinoIcons.book_fill,
    'other': CupertinoIcons.location_fill,
  };

  @override
  void initState() {
    super.initState();
    _radius = widget.zoneData?['radius']?.toDouble() ?? 200.0;
    _nameController = TextEditingController(text: widget.zoneData?['name'] ?? '');
    _selectedType = widget.zoneData?['type'] ?? 'home';
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
                            // Map Placeholder
                            Container(
                              color: _mapMode == 'satellite' 
                                  ? const Color(0xFF1E293B) 
                                  : const Color(0xFFE2E8F0),
                              child: CustomPaint(
                                painter: GridPainter(
                                  color: _mapMode == 'satellite' 
                                      ? Colors.white.withOpacity(0.1) 
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: Container(),
                              ),
                            ),

                            // Center Marker
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 56),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: _mapMode == 'satellite' 
                                            ? const Color(0xFF1E293B) 
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(24), // 1.5rem
                                        border: Border.all(
                                          color: _mapMode == 'satellite' 
                                              ? Colors.white.withOpacity(0.5) 
                                              : const Color(0xFFE2E8F0),
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _zoneIcons[_selectedType],
                                        color: _mapMode == 'satellite' 
                                            ? Colors.white 
                                            : const Color(0xFF475569),
                                        size: 32,
                                      ),
                                    ),
                                    Container(
                                      width: 8,
                                      height: 28,
                                      margin: const EdgeInsets.only(top: 4), // -mt-1 in React, adjusted
                                      decoration: BoxDecoration(
                                        color: (_mapMode == 'satellite' 
                                            ? Colors.white 
                                            : const Color(0xFF475569)).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Map Mode Toggle
                            Positioned(
                              bottom: 24,
                              left: 24,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_mapMode == 'street') _mapMode = 'satellite';
                                    else if (_mapMode == 'satellite') _mapMode = 'minimal';
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
                                      const Icon(
                                        CupertinoIcons.map,
                                        size: 20,
                                        color: Color(0xFF475569),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _mapMode == 'street' ? 'STANDARD' : _mapMode == 'satellite' ? 'SATELLITE' : 'MINIMAL',
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
                                  'TAP MAP TO MOVE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                      children: _zoneIcons.entries.map((entry) {
                        final isSelected = _selectedType == entry.key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = entry.key),
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
                                  entry.value,
                                  color: isSelected ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                  size: 24,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  entry.key.toUpperCase(),
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
                          onTap: () {
                            // Handle delete
                            Navigator.pop(context);
                          },
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
                onTap: () {
                  if (_nameController.text.isNotEmpty) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
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
                        CupertinoIcons.check_mark,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Save Settings',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
