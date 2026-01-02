import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class MedicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? medication;
  const MedicationDetailScreen({super.key, this.medication});

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  bool _isLogged = false;
  double _sliderPos = 0.0;
  final double _handleSize = 80.0;

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
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(64),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              image: const DecorationImage(
                                image: NetworkImage(
                                  'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&q=80&w=300&h=300&seed=med1',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Text(
                            widget.medication?['name'] ?? 'Amoxicillin',
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
                            '${widget.medication?['dose'] ?? '500mg'} • ${widget.medication?['instructions'] ?? 'Take with food'}',
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

                      // Info Grid
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
                            value: widget.medication?['dose'] ?? '500mg',
                          ),
                          _InfoBox(
                            icon: CupertinoIcons.clock,
                            label: 'Time',
                            value: widget.medication?['time'] ?? '08:00 AM',
                          ),
                          _InfoBox(
                            icon: CupertinoIcons.cube_box,
                            label: 'Supply',
                            value: '${((widget.medication?['currentStock'] ?? 36) / 3).floor()} Days', // Mock calc
                          ),
                          const _InfoBox(
                            icon: CupertinoIcons.pencil, // Edit3 equivalent
                            label: 'Frequency',
                            value: '3x a day',
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Schedule
                      Text(
                        "Today's Schedule",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const _ScheduleItem(
                        time: '08:00 AM',
                        status: 'Taken',
                        isCompleted: true,
                        isFirst: true,
                      ),
                      const _ScheduleItem(
                        time: '02:00 PM',
                        status: 'Upcoming',
                        isCompleted: false,
                      ),
                      const _ScheduleItem(
                        time: '08:00 PM',
                        status: 'Upcoming',
                        isCompleted: false,
                        isLast: true,
                      ),
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
