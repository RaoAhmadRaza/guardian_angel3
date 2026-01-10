import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/medication_model.dart';

class MedicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? medication;
  final MedicationModel? medicationModel;
  
  const MedicationDetailScreen({
    super.key, 
    this.medication,
    this.medicationModel,
  });

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  bool _isLogged = false;
  double _sliderPos = 0.0;
  final double _handleSize = 80.0;
  
  // Computed medication data
  String get _medicationName => 
      widget.medicationModel?.name ?? 
      widget.medication?['name'] as String? ?? 
      'Medication';
  
  String get _dose => 
      widget.medicationModel?.dose ?? 
      widget.medication?['dose'] as String? ?? 
      widget.medication?['dosage'] as String? ??
      '';
  
  String get _time {
    if (widget.medicationModel != null) {
      return _formatTime24To12(widget.medicationModel!.time);
    }
    return widget.medication?['time'] as String? ?? '08:00 AM';
  }
  
  int get _currentStock => 
      widget.medicationModel?.currentStock ?? 
      widget.medication?['currentStock'] as int? ?? 
      30;
  
  String get _medicationType => 
      widget.medicationModel?.type ?? 
      widget.medication?['subType'] as String? ?? 
      'pill';
  
  String get _instructions => 
      widget.medication?['instructions'] as String? ?? 
      'Take as directed';
  
  int get _frequency {
    // Try to get frequency from medication data
    final freq = widget.medication?['frequency'] as int?;
    if (freq != null) return freq;
    
    // Default based on type
    if (_medicationType == 'infusion') return 1;
    return 1; // Default to 1x per day
  }
  
  /// Calculate supply days based on stock and frequency
  int get _supplyDays => _frequency > 0 ? (_currentStock / _frequency).floor() : _currentStock;
  
  /// Format 24h time to 12h format
  String _formatTime24To12(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
  
  /// Generate schedule items based on medication time and frequency
  List<_ScheduleData> _generateSchedule() {
    final schedules = <_ScheduleData>[];
    
    // Parse the base time
    String baseTime = widget.medicationModel?.time ?? '08:00';
    final parts = baseTime.split(':');
    int baseHour = int.tryParse(parts[0]) ?? 8;
    int baseMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    
    // Generate schedule based on frequency
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    
    for (int i = 0; i < _frequency; i++) {
      // Calculate time for each dose (spread throughout the day)
      int doseHour = (baseHour + (i * (12 ~/ _frequency))) % 24;
      
      final time = _formatTime24To12('${doseHour.toString().padLeft(2, '0')}:${baseMinute.toString().padLeft(2, '0')}');
      
      // Determine status based on current time
      bool isCompleted = false;
      String status = 'Upcoming';
      
      if (doseHour < currentHour || (doseHour == currentHour && baseMinute <= currentMinute)) {
        // Past dose time - check if logged
        isCompleted = _isLogged && i == 0; // First dose is logged via slider
        status = isCompleted ? 'Taken' : 'Missed';
      }
      
      schedules.add(_ScheduleData(
        time: time,
        status: status,
        isCompleted: isCompleted,
      ));
    }
    
    // If no schedule items (frequency 0), add at least one
    if (schedules.isEmpty) {
      schedules.add(_ScheduleData(
        time: _time,
        status: _isLogged ? 'Taken' : 'Upcoming',
        isCompleted: _isLogged,
      ));
    }
    
    return schedules;
  }
  
  /// Get frequency text
  String _getFrequencyText() {
    switch (_frequency) {
      case 1:
        return 'Once daily';
      case 2:
        return 'Twice daily';
      case 3:
        return '3x a day';
      case 4:
        return '4x a day';
      default:
        return '$_frequency x daily';
    }
  }
  
  /// Get medication icon based on type
  IconData _getMedicationIcon() {
    switch (_medicationType.toLowerCase()) {
      case 'capsule':
        return CupertinoIcons.capsule;
      case 'liquid':
      case 'infusion':
        return CupertinoIcons.drop_fill;
      case 'injection':
        return Icons.vaccines;
      default:
        return CupertinoIcons.capsule_fill;
    }
  }
  
  /// Get medication color based on type
  Color _getMedicationColor() {
    switch (_medicationType.toLowerCase()) {
      case 'capsule':
        return const Color(0xFFEFF6FF); // Blue tint
      case 'liquid':
      case 'infusion':
        return const Color(0xFFFFF7ED); // Orange tint
      case 'injection':
        return const Color(0xFFF0FDF4); // Green tint
      default:
        return const Color(0xFFF5F3FF); // Purple tint
    }
  }
  
  /// Get medication icon color based on type
  Color _getMedicationIconColor() {
    switch (_medicationType.toLowerCase()) {
      case 'capsule':
        return const Color(0xFF2563EB); // Blue
      case 'liquid':
      case 'infusion':
        return const Color(0xFFEA580C); // Orange
      case 'injection':
        return const Color(0xFF16A34A); // Green
      default:
        return const Color(0xFF7C3AED); // Purple
    }
  }
  
  /// Build schedule items dynamically
  List<Widget> _buildScheduleItems() {
    final schedules = _generateSchedule();
    if (schedules.isEmpty) {
      return [
        Center(
          child: Text(
            'No scheduled doses',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ];
    }
    
    return schedules.asMap().entries.map((entry) {
      final index = entry.key;
      final schedule = entry.value;
      
      return _ScheduleItem(
        time: schedule.time,
        status: schedule.status,
        isCompleted: schedule.isCompleted,
        isFirst: index == 0,
        isLast: index == schedules.length - 1,
      );
    }).toList();
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isLogged) return;
    
    setState(() {
      // 40 padding (20 left + 20 right) + handle size
      double maxDrag = maxWidth - _handleSize - 16; // 16 is padding inside slider
      double newPos = _sliderPos + details.delta.dx;
      _sliderPos = newPos.clamp(0.0, maxDrag);
      
      if (_sliderPos >= maxDrag * 0.9) {
        _isLogged = true;
        _sliderPos = maxDrag;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isLogged) {
      setState(() {
        _sliderPos = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Row(
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
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Medicine Details',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
                    children: [
                      // Medicine Visual
                      Column(
                        children: [
                          Container(
                            width: 256,
                            height: 256,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: _getMedicationColor(),
                              borderRadius: BorderRadius.circular(64),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _getMedicationIcon(),
                                size: 100,
                                color: _getMedicationIconColor(),
                              ),
                            ),
                          ),
                          Text(
                            _medicationName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_dose • $_instructions',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Info Grid - Using dynamic data
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.25,
                        children: [
                          _InfoBox(
                            icon: CupertinoIcons.doc_text,
                            label: 'Dose',
                            value: _dose.isNotEmpty ? _dose : 'N/A',
                          ),
                          _InfoBox(
                            icon: CupertinoIcons.clock,
                            label: 'Time',
                            value: _time,
                          ),
                          _InfoBox(
                            icon: CupertinoIcons.cube_box,
                            label: 'Supply',
                            value: '$_supplyDays Days',
                          ),
                          _InfoBox(
                            icon: CupertinoIcons.calendar,
                            label: 'Frequency',
                            value: _getFrequencyText(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Schedule - Using dynamic data
                      Text(
                        "Today's Schedule",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Dynamic schedule items
                      ..._buildScheduleItems(),
                    ],
                  ),
                ),
              ],
            ),

            // Slider
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: _isLogged ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: _isLogged ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              _isLogged ? 'DOSE LOGGED ✓' : 'SLIDE TO LOG DOSE',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: _isLogged ? Colors.white : const Color(0xFF64748B),
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          if (!_isLogged)
                            Positioned(
                              left: 8 + _sliderPos,
                              top: 6,
                              bottom: 6,
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) => 
                                    _handleDragUpdate(details, constraints.maxWidth),
                                onHorizontalDragEnd: _handleDragEnd,
                                child: Container(
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      CupertinoIcons.chevron_right,
                                      color: Color(0xFF0F172A),
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFF2563EB),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String time;
  final String status;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  const _ScheduleItem({
    required this.time,
    required this.status,
    required this.isCompleted,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Line & Dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top Line
                Expanded(
                  child: !isFirst
                      ? Container(
                          width: 2,
                          color: isCompleted ? const Color(0xFF059669) : null,
                          decoration: !isCompleted
                              ? const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 2,
                                      style: BorderStyle.solid, // Dashed difficult in basic Container, using solid for simplicity or CustomPainter if strict
                                    ),
                                  ),
                                )
                              : null,
                        )
                      : const SizedBox(),
                ),
                
                // Dot
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF059669) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            color: Colors.white,
                            size: 16,
                          )
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),

                // Bottom Line
                Expanded(
                  child: !isLast
                      ? Container(
                          width: 2,
                          color: isCompleted ? const Color(0xFF059669) : null,
                          decoration: !isCompleted
                              ? const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                )
                              : null,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 24),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isCompleted ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isCompleted ? '✓ 10:02 AM' : 'Pending',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isCompleted ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class to hold schedule information
class _ScheduleData {
  final String time;
  final String status;
  final bool isCompleted;

  const _ScheduleData({
    required this.time,
    required this.status,
    required this.isCompleted,
  });
}
