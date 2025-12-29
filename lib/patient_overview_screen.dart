import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/patient_model.dart';
import 'reports_screen.dart';
import 'chat_screen.dart';
import 'clinical_findings_screen.dart';
import 'schedule_screen.dart';

class PatientOverviewScreen extends StatelessWidget {
  final Patient patient;

  const PatientOverviewScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50 background to match context
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), // Slate-900
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ),
            _buildPatientHub(context),
            const SizedBox(height: 16),
            _buildVitalsOverview(),
            const SizedBox(height: 16),
            _buildVitalsChartCard(),
            const SizedBox(height: 16),
            _buildMedicationsAndAlerts(),
            const SizedBox(height: 20), // Bottom spacing
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHub(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Image
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFF8FAFC), width: 4), // Slate-50
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.network(
                patient.photo,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(
                  width: 96,
                  height: 96,
                  color: Colors.grey[200],
                  child: const Icon(Icons.person, size: 48, color: Colors.grey),
                ),
              ),
            ),
          ),
          
          // Name & Info
          Text(
            patient.name,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A), // Slate-900
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${patient.age} Yrs • GA-${patient.id.padLeft(3, '0')}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B), // Slate-500
            ),
          ),
          const SizedBox(height: 16),

          // Action Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildActionButton(
                      label: 'Message',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF2563EB), // Blue-600
                      shadowColor: const Color(0xFFDBEAFE), // Blue-100
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(patient: patient),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      label: 'Reports',
                      icon: Icons.description_outlined,
                      color: const Color(0xFF4F46E5), // Indigo-600
                      shadowColor: const Color(0xFFE0E7FF), // Indigo-100
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReportsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildActionButton(
                      label: 'Schedule',
                      icon: Icons.calendar_today_rounded,
                      color: const Color(0xFF0F172A), // Slate-900
                      shadowColor: const Color(0xFFE2E8F0), // Slate-200
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScheduleScreen(patient: patient),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      label: 'Findings',
                      icon: Icons.assignment_outlined,
                      color: const Color(0xFF9333EA), // Purple-600
                      shadowColor: const Color(0xFFF3E8FF), // Purple-100
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClinicalFindingsScreen(patient: patient),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color shadowColor,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsOverview() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildVitalCard(
            label: 'Pulse',
            value: '76',
            unit: 'bpm',
            bgColor: const Color(0xFFECFDF5), // Emerald-50
            borderColor: const Color(0xFFD1FAE5), // Emerald-100
            textColor: const Color(0xFF059669), // Emerald-600
          ),
          const SizedBox(width: 12),
          _buildVitalCard(
            label: 'O2 Sat',
            value: '98',
            unit: '%',
            bgColor: const Color(0xFFEFF6FF), // Blue-50
            borderColor: const Color(0xFFDBEAFE), // Blue-100
            textColor: const Color(0xFF2563EB), // Blue-600
          ),
          const SizedBox(width: 12),
          _buildVitalCard(
            label: 'Sleep',
            value: '8.2',
            unit: 'h',
            bgColor: const Color(0xFFFFFBEB), // Amber-50
            borderColor: const Color(0xFFFEF3C7), // Amber-100
            textColor: const Color(0xFFD97706), // Amber-600
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required String label,
    required String value,
    required String unit,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A), // Slate-900
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8), // Slate-400
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Heart Rate Trend',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A), // Slate-900
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Blue-50
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '24H VIEW',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2563EB), // Blue-600
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 192, // h-48
            width: double.infinity,
            child: CustomPaint(
              painter: ChartPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsAndAlerts() {
    return Column(
      children: [
        // Medications
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
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
            children: [
              Text(
                'Medications',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A), // Slate-900
                ),
              ),
              const SizedBox(height: 16),
              _buildMedicationItem('Lisinopril', '10mg • Daily', '98'),
              const Divider(height: 32, color: Color(0xFFF8FAFC)),
              _buildMedicationItem('Metoprolol', '50mg • Twice Daily', '85'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Alerts
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2).withOpacity(0.5), // Rose-50/50
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFE4E6).withOpacity(0.5)), // Rose-100/50
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
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Alerts',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF881337), // Rose-900
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFE4E6).withOpacity(0.3)),
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
                  children: [
                    Text(
                      'Irregular Rhythm Detected',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A), // Slate-900
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today at 04:32 AM',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8), // Slate-400
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationItem(String name, String dosage, String adherence) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A), // Slate-900
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dosage,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B), // Slate-500
              ),
            ),
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC), // Slate-50
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$adherence%',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2563EB), // Blue-600
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6) // Blue-500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Mock data points to simulate the curve
    final points = [
      const Offset(0, 0.7),
      const Offset(0.1, 0.6),
      const Offset(0.2, 0.65),
      const Offset(0.3, 0.4),
      const Offset(0.4, 0.5),
      const Offset(0.5, 0.3),
      const Offset(0.6, 0.45),
      const Offset(0.7, 0.2),
      const Offset(0.8, 0.3),
      const Offset(0.9, 0.1),
      const Offset(1.0, 0.25),
    ];

    path.moveTo(0, size.height * points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = Offset(points[i].dx * size.width, points[i].dy * size.height);
      final p2 = Offset(points[i+1].dx * size.width, points[i+1].dy * size.height);
      
      // Simple cubic bezier for smoothness
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Draw the line
    canvas.drawPath(path, paint);

    // Draw the gradient fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x263B82F6), // Blue-500 with 0.15 opacity
          Color(0x003B82F6), // Blue-500 with 0 opacity
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF8FAFC) // Slate-50
      ..strokeWidth = 1;

    for (int i = 1; i < 5; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
