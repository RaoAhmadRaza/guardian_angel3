import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Mock Data
class Report {
  final String id;
  final String type;
  final String date;
  final String source;

  Report({
    required this.id,
    required this.type,
    required this.date,
    required this.source,
  });
}

final List<Report> mockReports = [
  Report(id: '1', type: 'Blood Work Analysis', date: 'Oct 24, 2023', source: 'Central Lab'),
  Report(id: '2', type: 'Cardiology Consult', date: 'Oct 20, 2023', source: 'Dr. Smith'),
  Report(id: '3', type: 'MRI Scan Results', date: 'Oct 15, 2023', source: 'Imaging Center'),
  Report(id: '4', type: 'Annual Physical', date: 'Sep 30, 2023', source: 'General Practice'),
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedReportId;
  bool _isLoading = false;
  Map<String, dynamic>? _summary;

  void _handleSummarize() async {
    setState(() => _isLoading = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _summary = {
        'summary': 'Patient exhibits stable respiratory patterns. Labs indicate elevated glucose at 124 mg/dL. Cardiovascular rhythm is Sinus. Recommendation: Monitor glucose levels weekly.',
        'keyFindings': [
          'Elevated Glucose (124 mg/dL)',
          'Stable Respiratory Patterns',
          'Sinus Rhythm Confirmed',
        ]
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50
      body: SafeArea(
        child: _selectedReportId != null ? _buildDetailView() : _buildListView(),
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, right: 12.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), // Slate-900
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLINICAL VAULT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF94A3B8), // Slate-400
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient Reports',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A), // Slate-900
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List
          ...mockReports.map((report) => _buildReportItem(report)),
        ],
      ),
    );
  }

  Widget _buildReportItem(Report report) {
    return GestureDetector(
      onTap: () => setState(() => _selectedReportId = report.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)), // Slate-100
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Blue-50
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 24), // Blue-600
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.type,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A), // Slate-900
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${report.date} • ${report.source}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8), // Slate-400
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20), // Slate-300
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final report = mockReports.firstWhere((r) => r.id == _selectedReportId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          GestureDetector(
            onTap: () => setState(() {
              _selectedReportId = null;
              _summary = null;
            }),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, color: Color(0xFF2563EB), size: 20), // Blue-600
                  const SizedBox(width: 4),
                  Text(
                    'Back to List',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB), // Blue-600
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Main Card
          Container(
            padding: const EdgeInsets.all(24),
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
                  report.type,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A), // Slate-900
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${report.date} • ${report.source}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8), // Slate-400
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSummarize,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5), // Indigo-600
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFE0E7FF), // Indigo-100
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isLoading) ...[
                              const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isLoading ? 'Analyzing...' : 'AI Summary',
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Slate-100
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Original',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569), // Slate-600
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Content Area
                if (_summary != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF).withOpacity(0.5), // Indigo-50/50
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE0E7FF).withOpacity(0.5)), // Indigo-100/50
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary!['summary'],
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B), // Slate-800
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'FINDINGS',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF4F46E5), // Indigo-600
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_summary!['keyFindings'] as List<String>).map((finding) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '•',
                                style: TextStyle(
                                  color: Color(0xFF818CF8), // Indigo-400
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  finding,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF475569), // Slate-600
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 256, // h-64
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // Slate-50
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF1F5F9), // Slate-100
                        style: BorderStyle.solid, // Dashed border not natively supported easily without package, using solid for now or custom painter if strict
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 48, color: const Color(0xFFCBD5E1).withOpacity(0.5)), // Slate-400 opacity 30
                        const SizedBox(height: 8),
                        Text(
                          'Document Preview Encrypted',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
