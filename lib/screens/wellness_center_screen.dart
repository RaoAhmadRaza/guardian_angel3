import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guardian_angel_fyp/screens/exercise_arena_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TYPES & CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

enum ExerciseType {
  memoryRecall,
  patternMatch,
  wordAssociation,
  emotionalReflection,
  focusBreathing,
}

class ExerciseData {
  final ExerciseType id;
  final String title;
  final String description;
  final String goal;
  final String icon;
  final String instruction;
  final int difficulty;
  final String duration;
  final Color themeColor;
  final Color accentColor;

  const ExerciseData({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.icon,
    required this.instruction,
    required this.difficulty,
    required this.duration,
    required this.themeColor,
    required this.accentColor,
  });
}

const List<ExerciseData> exercises = [
  ExerciseData(
    id: ExerciseType.memoryRecall,
    title: 'Memory Recall',
    description: 'Gently remember simple details.',
    goal: 'Short-term memory retention',
    icon: '🧠',
    instruction: 'Take a moment to look at these items. In a few seconds, they will disappear, and you can tell me which ones you remember.',
    difficulty: 2,
    duration: '3 min',
    themeColor: Color(0xFFEFF6FF), // bg-blue-50
    accentColor: Color(0xFF2563EB), // text-blue-600
  ),
  ExerciseData(
    id: ExerciseType.patternMatch,
    title: 'Pattern Match',
    description: 'Spot visual patterns.',
    goal: 'Visual processing + focus',
    icon: '🧩',
    instruction: 'Look at the group of shapes below. One of them is slightly different from the others. Can you find it?',
    difficulty: 2,
    duration: '2 min',
    themeColor: Color(0xFFFAF5FF), // bg-purple-50
    accentColor: Color(0xFF9333EA), // text-purple-600
  ),
  ExerciseData(
    id: ExerciseType.wordAssociation,
    title: 'Word Association',
    description: 'Think of related words.',
    goal: 'Language + cognition',
    icon: '💬',
    instruction: 'I will show you a word. Simply choose the word that feels most related to it for you. There are no wrong answers.',
    difficulty: 1,
    duration: '2 min',
    themeColor: Color(0xFFFFFBEB), // bg-amber-50
    accentColor: Color(0xFFD97706), // text-amber-600
  ),
  ExerciseData(
    id: ExerciseType.emotionalReflection,
    title: 'Emotional Reflection',
    description: 'Notice and name feelings.',
    goal: 'Emotional awareness',
    icon: '🌿',
    instruction: 'Take a quiet moment to check in with yourself. How are you feeling right now?',
    difficulty: 1,
    duration: '1 min',
    themeColor: Color(0xFFF0FDF4), // bg-green-50
    accentColor: Color(0xFF16A34A), // text-green-600
  ),
  ExerciseData(
    id: ExerciseType.focusBreathing,
    title: 'Focus Breathing',
    description: 'Combine breath with thought.',
    goal: 'Mental clarity',
    icon: '🌬️',
    instruction: 'Follow the circle as it expands and contracts. Breathe in as it grows, and out as it shrinks.',
    difficulty: 1,
    duration: '3 min',
    themeColor: Color(0xFFFFF1F2), // bg-rose-50
    accentColor: Color(0xFFE11D48), // text-rose-600
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class WellnessCenterScreen extends StatefulWidget {
  const WellnessCenterScreen({super.key});

  @override
  State<WellnessCenterScreen> createState() => _WellnessCenterScreenState();
}

class _WellnessCenterScreenState extends State<WellnessCenterScreen> {
  bool _showInfo = false;

  void _onSelectExercise(ExerciseType type) {
    final exercise = exercises.firstWhere((e) => e.id == type);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExerciseArenaScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF7), // bg-[#FCFAF7]
      body: Stack(
        children: [
          Column(
            children: [
              // Top Navigation - Calm & Clear
              _buildHeader(),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  children: [
                    // Daily Highlight Card
                    _buildDailyHighlightCard(),

                    const SizedBox(height: 40),

                    // Simplified Exercise List
                    _buildExerciseList(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),

          // Simplified Info Modal
          if (_showInfo) _buildInfoModal(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF7).withOpacity(0.9),
        border: Border(bottom: BorderSide(color: const Color(0xFFF5F5F4))), // border-stone-100
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE7E5E4)), // border-stone-200
                ),
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  size: 20,
                  color: Color(0xFFA8A29E), // text-stone-400
                ),
              ),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Guardian Angel',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900, // Blocky & Bold
                    color: const Color(0xFF292524), // text-stone-800
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DAILY WELLNESS CENTER',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA8A29E), // text-stone-400
                    letterSpacing: 2.4, // tracking-[0.2em]
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _showInfo = true),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F4), // bg-stone-100
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.info,
                  color: Color(0xFF57534E), // text-stone-600
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyHighlightCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF292524), // bg-stone-800
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // shadow-2xl approximation
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Sun Icon
          Positioned(
            top: 32,
            right: 32,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                CupertinoIcons.sun_max_fill,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEATURED ACTIVITY',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA8A29E), // text-stone-400
                    letterSpacing: 1.2, // tracking-widest
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Memory Recall',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w900, // Blocky & Bold
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  child: Text(
                    'A gentle way to sharpen your focus this morning.',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      height: 1.625, // leading-relaxed
                      color: const Color(0xFFD6D3D1), // text-stone-300
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => _onSelectExercise(ExerciseType.memoryRecall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DACE), // bg-[#E5DACE]
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1), // shadow-xl approximation
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.play_fill,
                          size: 24,
                          color: Color(0xFF1C1917), // text-stone-900
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Begin Now',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1917), // text-stone-900
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms);
  }

  Widget _buildExerciseList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPLORE ACTIVITIES',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900, // font-black
            color: const Color(0xFFA8A29E), // text-stone-400
            letterSpacing: 1.2, // tracking-widest
          ),
        ),
        const SizedBox(height: 24),
        Column(
          children: exercises.map((ex) => _buildExerciseItem(ex)).toList(),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(ExerciseData ex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () => _onSelectExercise(ex.id),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFE7E5E4)), // border-stone-200
            // hover:shadow-md is handled by interaction, but we can add a subtle shadow
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAF9), // bg-stone-50
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  ex.icon,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.title,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900, // Blocky & Bold
                        color: const Color(0xFF292524), // text-stone-800
                        height: 1.25, // leading-tight
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ex.duration} • Gentle Focus',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF78716C), // text-stone-500
                      ),
                    ),
                  ],
                ),
              ),

              // Play Icon
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Icon(
                  CupertinoIcons.play_fill,
                  size: 24,
                  color: Color(0xFFD6D3D1), // text-stone-300
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoModal() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () => setState(() => _showInfo = false),
          child: Container(
            color: const Color(0xFF1C1917).withOpacity(0.4), // bg-stone-900/40
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.transparent),
            ),
          ),
        ).animate().fadeIn(duration: 500.ms),

        // Modal Content
        Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25), // shadow-2xl
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w900, // Blocky & Bold
                    color: const Color(0xFF292524), // text-stone-800
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Guardian Angel is designed for peaceful mental exercise. There are no timers, no scores, and no rush.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    height: 1.625, // leading-relaxed
                    color: const Color(0xFF57534E), // text-stone-600
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => setState(() => _showInfo = false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF292524), // bg-stone-800
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1), // shadow-lg
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
        ),
      ],
    );
  }
}
