import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/patient_model.dart';

enum NoteVisibility {
  doctorOnly,
  shared,
}

class ClinicalNote {
  final String id;
  final String content;
  final String timestamp;
  final NoteVisibility visibility;

  ClinicalNote({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.visibility,
  });
}

final List<ClinicalNote> initialNotes = [
  ClinicalNote(
    id: 'n1',
    content: 'Patient reports mild fatigue after morning walks. Adjusting sodium intake.',
    timestamp: 'Oct 25, 2023',
    visibility: NoteVisibility.shared,
  ),
  ClinicalNote(
    id: 'n2',
    content: 'Observation: Blood pressure slightly elevated during night cycles.',
    timestamp: 'Oct 22, 2023',
    visibility: NoteVisibility.doctorOnly,
  ),
];

class ClinicalFindingsScreen extends StatefulWidget {
  final Patient patient;

  const ClinicalFindingsScreen({super.key, required this.patient});

  @override
  State<ClinicalFindingsScreen> createState() => _ClinicalFindingsScreenState();
}

class _ClinicalFindingsScreenState extends State<ClinicalFindingsScreen> {
  final List<ClinicalNote> _notes = List.from(initialNotes);
  final TextEditingController _noteController = TextEditingController();
  NoteVisibility _currentVisibility = NoteVisibility.doctorOnly;

  void _addNote() {
    if (_noteController.text.trim().isEmpty) return;

    setState(() {
      _notes.insert(0, ClinicalNote(
        id: DateTime.now().toString(),
        content: _noteController.text,
        timestamp: 'Oct 29, 2025', // Using current date as per context
        visibility: _currentVisibility,
      ));
      _noteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-50
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), // Slate-900
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OBSERVATION LOG',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8), // Slate-400
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clinical Notes',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A), // Slate-900
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Input Area
            Container(
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
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Clinical findings...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8), // Slate-400
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC), // Slate-50
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF0F172A), // Slate-900
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Visibility Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Slate-100
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _currentVisibility = NoteVisibility.doctorOnly),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _currentVisibility == NoteVisibility.doctorOnly 
                                    ? Colors.white 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _currentVisibility == NoteVisibility.doctorOnly
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'PRIVATE',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _currentVisibility == NoteVisibility.doctorOnly
                                        ? const Color(0xFF0F172A) // Slate-900
                                        : const Color(0xFF94A3B8), // Slate-400
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _currentVisibility = NoteVisibility.shared),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _currentVisibility == NoteVisibility.shared 
                                    ? Colors.white 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _currentVisibility == NoteVisibility.shared
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'SHARE WITH TEAM',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _currentVisibility == NoteVisibility.shared
                                        ? const Color(0xFF0F172A) // Slate-900
                                        : const Color(0xFF94A3B8), // Slate-400
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB), // Blue-600
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFFDBEAFE), // Blue-100
                      ),
                      child: Text(
                        'Save Record',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes List
            ..._notes.map((note) => _buildNoteCard(note)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(ClinicalNote note) {
    final isShared = note.visibility == NoteVisibility.shared;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                note.timestamp.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFCBD5E1), // Slate-300
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isShared ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9), // Emerald-50 : Slate-100
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isShared ? 'SHARED' : 'PRIVATE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isShared ? const Color(0xFF059669) : const Color(0xFF64748B), // Emerald-600 : Slate-500
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF334155), // Slate-700
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF8FAFC))), // Slate-50
            ),
            child: Row(
              children: [
                Text(
                  'EDIT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2563EB), // Blue-600
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'ARCHIVE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFB7185), // Rose-400
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
