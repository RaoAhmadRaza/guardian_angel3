import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class CalendarOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const CalendarOverlay({Key? key, required this.onClose}) : super(key: key);

  @override
  _CalendarOverlayState createState() => _CalendarOverlayState();
}

class _CalendarOverlayState extends State<CalendarOverlay> {
  // Mock data matching the React component
  final List<String> _weekDays = ["M", "T", "W", "T", "F", "S", "S"];
  final List<int> _days = List.generate(31, (index) => index + 1);
  final List<int> _indicatorDays = [17, 18, 19, 21];
  final int _selectedDay = 19;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Backdrop with blur
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: const Color(0xFF0F172A).withOpacity(0.4),
                ),
              ),
            ),
          ),
          // Calendar Card
          Positioned(
            top: 100, // pt-24 approx 96px
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.92,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25), // shadow-2xl approximation
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildCalendarGrid(),
                    const SizedBox(height: 32),
                    _buildCloseButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'March 2024',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            _buildHeaderButton(
              icon: CupertinoIcons.chevron_left,
              onTap: () {},
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            _buildHeaderButton(
              icon: CupertinoIcons.chevron_right,
              onTap: () {},
              isPrimary: false,
            ),
            const SizedBox(width: 8),
            _buildHeaderButton(
              icon: CupertinoIcons.xmark,
              onTap: widget.onClose,
              isPrimary: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : const Color(0xFF0F172A),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return Column(
      children: [
        // Weekday Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _weekDays.map((day) {
            return SizedBox(
              width: 40, // Approximate width for grid alignment
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.5,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 12,
            crossAxisSpacing: 0, // Spacing handled by container size/alignment
            childAspectRatio: 1.0,
          ),
          itemCount: _days.length,
          itemBuilder: (context, index) {
            final day = _days[index];
            final isSelected = day == _selectedDay;
            final hasIndicator = _indicatorDays.contains(day);

            return GestureDetector(
              onTap: widget.onClose,
              child: Container(
                margin: const EdgeInsets.all(2), // slight margin
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$day',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (hasIndicator)
                      Positioned(
                        bottom: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF34D399) : const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'Close Calendar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
