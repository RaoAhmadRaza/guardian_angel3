import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guardian_angel_fyp/screens/wellness_center_screen.dart';
import 'package:guardian_angel_fyp/screens/completion_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE ARENA SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ExerciseArenaScreen extends StatefulWidget {
  final ExerciseData exercise;

  const ExerciseArenaScreen({super.key, required this.exercise});

  @override
  State<ExerciseArenaScreen> createState() => _ExerciseArenaScreenState();
}

class _ExerciseArenaScreenState extends State<ExerciseArenaScreen> {
  bool _started = false;

  bool get _isArcadeMode =>
      _started &&
      (widget.exercise.id == ExerciseType.patternMatch ||
          widget.exercise.id == ExerciseType.focusBreathing);

  void _handleBack() {
    if (_started) {
      setState(() => _started = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleFinish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CompletionScreen(
          onDone: () => Navigator.of(context).pop(),
          onTryAnother: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isArcadeMode ? const Color(0xFFFCFAF7) : Colors.white,
      body: Column(
        children: [
          // Standard Top Bar - Elegant & Senior Friendly
          if (!_isArcadeMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF5F5F4))), // border-stone-100
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _handleBack,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.transparent,
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          size: 32,
                          color: Color(0xFFA8A29E), // text-stone-400
                        ),
                      ),
                    ),
                    Text(
                      widget.exercise.title,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w900, // Blocky & Bold
                        color: const Color(0xFF292524), // text-stone-800
                      ),
                    ),
                    const SizedBox(width: 40), // Spacer for balance
                  ],
                ),
              ),
            ),

          // Content Area
          Expanded(
            child: _started
                ? _buildActiveExercise()
                : _buildInstructionCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAF9), // bg-stone-50
                        borderRadius: BorderRadius.circular(48),
                        border: Border.all(color: const Color(0xFFF5F5F4), width: 2), // border-stone-100
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.exercise.icon,
                            style: const TextStyle(fontSize: 96),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            widget.exercise.instruction,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 30,
                              fontWeight: FontWeight.w900, // Blocky & Bold
                              color: const Color(0xFF292524), // text-stone-800
                              height: 1.625, // leading-relaxed
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 700.ms),
                    const SizedBox(height: 48),
                    GestureDetector(
                      onTap: () => setState(() => _started = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292524), // bg-stone-800
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25), // shadow-2xl
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Start',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 700.ms, delay: 200.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveExercise() {
    switch (widget.exercise.id) {
      case ExerciseType.memoryRecall:
        return _MemoryRecallView(onComplete: _handleFinish);
      case ExerciseType.patternMatch:
        return _PatternMatchView(onComplete: _handleFinish, onBack: _handleBack);
      case ExerciseType.wordAssociation:
        return _WordAssociationView(onComplete: _handleFinish);
      case ExerciseType.emotionalReflection:
        return _EmotionalReflectionView(onComplete: _handleFinish);
      case ExerciseType.focusBreathing:
        return _FocusBreathingView(onComplete: _handleFinish, onBack: _handleBack);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY RECALL
// ═══════════════════════════════════════════════════════════════════════════

class _MemoryRecallView extends StatefulWidget {
  final VoidCallback onComplete;

  const _MemoryRecallView({required this.onComplete});

  @override
  State<_MemoryRecallView> createState() => _MemoryRecallViewState();
}

class _MemoryRecallViewState extends State<_MemoryRecallView> {
  static const List<String> _allItems = ['🍎', '📚', '🍵', '🏠', '⌚', '🗝️', '📱', '🧢', '🚲', '🧤'];
  
  String _phase = 'memorize'; // memorize | recall
  List<String> _targetItems = [];
  List<String> _choices = [];
  final List<String> _selectedItems = [];
  double _timeLeft = 7.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final shuffled = List<String>.from(_allItems)..shuffle();
    _targetItems = shuffled.take(3).toList();
    final others = shuffled.skip(3).take(3).toList();
    _choices = [..._targetItems, ...others]..shuffle();

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        if (_timeLeft <= 0.1) {
          _phase = 'recall';
          _timer?.cancel();
          _timeLeft = 0;
        } else {
          _timeLeft -= 0.1;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleSelect(String item) {
    if (_selectedItems.contains(item)) return;
    
    setState(() {
      _selectedItems.add(item);
    });

    if (_selectedItems.length >= 3) {
      Future.delayed(const Duration(milliseconds: 1500), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFCFAF7), // bg-[#FCFAF7]
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_phase == 'memorize') ...[
                      Text(
                        'Take a moment to remember...',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w900, // Blocky & Bold
                          color: const Color(0xFF292524), // text-stone-800
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 1000.ms),
                      
                      const SizedBox(height: 48),

                      // Progress Bar
                      Container(
                        width: 320,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F4), // bg-stone-100
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE7E5E4)), // border-stone-200
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _timeLeft / 7.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF292524), // bg-stone-800
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 64),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _targetItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _buildCard(item, false),
                        )).toList(),
                      ),
                    ] else ...[
                      Text(
                        'Which items did you see?',
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w900, // Blocky & Bold
                          color: const Color(0xFF292524), // text-stone-800
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(duration: 1000.ms),

                      const SizedBox(height: 64),

                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: _choices.map((item) => GestureDetector(
                          onTap: () => _handleSelect(item),
                          child: _buildCard(item, _selectedItems.contains(item)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Subtle Exit Button (replicated from ExerciseScreen logic)
          Container(
            height: 96,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFFAFAF9))), // border-stone-50
            ),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: widget.onComplete,
              child: Text(
                'SKIP TO FINISH',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA8A29E), // text-stone-400
                  letterSpacing: 1.2, // tracking-widest
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String item, bool isSelected) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFAFAF9) : Colors.white, // bg-stone-50 : bg-white
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isSelected ? const Color(0xFF292524) : const Color(0xFFF5F5F4), // border-stone-800 : border-stone-100
          width: 2,
        ),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Text(
            item,
            style: const TextStyle(fontSize: 60),
          ),
          if (isSelected)
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF292524), // bg-stone-800
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.checkmark,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PATTERN MATCH
// ═══════════════════════════════════════════════════════════════════════════

class _PatternMatchView extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const _PatternMatchView({required this.onComplete, required this.onBack});

  @override
  State<_PatternMatchView> createState() => _PatternMatchViewState();
}

class _PatternMatchViewState extends State<_PatternMatchView> {
  static const List<String> _shapes = [
    'triangle',
    'square',
    'circle',
    'diamond',
  ];

  List<_PatternItem> _items = [];
  int? _feedbackIndex;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final random = Random();
    final baseShape = _shapes[random.nextInt(_shapes.length)];
    final oddIndex = random.nextInt(6);

    _items = List.generate(6, (index) {
      return _PatternItem(
        id: index,
        shape: baseShape,
        isOdd: index == oddIndex,
        rotation: index == oddIndex ? 45.0 : 0.0,
      );
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleSelect(int index) {
    if (_feedbackIndex != null) return;

    setState(() {
      _feedbackIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 1500), widget.onComplete);
  }

  String _formatTime(int s) {
    final mins = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5), // bg-[#F0F2F5]
      child: Stack(
        children: [
          // Radial Focus Glow Background
          Positioned.fill(
            child: Center(
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ).animate().blur(begin: const Offset(120, 120), end: const Offset(120, 120)),
            ),
          ),

          Column(
            children: [
              // HUD: Floating Glass Status Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 20,
                            color: Color(0xFF475569), // text-slate-600
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildHudChip(
                            icon: CupertinoIcons.timer,
                            text: _formatTime(_seconds),
                            iconColor: const Color(0xFF64748B), // text-slate-500
                          ),
                          const SizedBox(width: 8),
                          _buildHudChip(
                            icon: CupertinoIcons.flame_fill,
                            text: 'ROUND 1/1',
                            iconColor: const Color(0xFFF97316), // text-orange-500
                          ),
                        ],
                      ),
                      const SizedBox(width: 40), // Spacer
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Spot the odd shape',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900, // font-black
                            color: const Color(0xFF1E293B), // text-slate-800
                            letterSpacing: -0.5, // tracking-tight
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 3D "Squircle" Buttons Grid
                        SizedBox(
                          width: 320,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isSelected = _feedbackIndex == index;
                              final isCorrect = item.isOdd;

                              Color bgColor = Colors.white;
                              Color borderColor = const Color(0xFFF1F5F9); // border-slate-100
                              double offsetY = 0;
                              double shadowBlur = 24;

                              if (isSelected) {
                                offsetY = 4;
                                shadowBlur = 0;
                                if (isCorrect) {
                                  bgColor = const Color(0xFFF0FDF4); // bg-green-50
                                  borderColor = const Color(0xFF22C55E); // border-green-500
                                } else {
                                  bgColor = const Color(0xFFFFF1F2); // bg-rose-50
                                  borderColor = const Color(0xFFF43F5E); // border-rose-500
                                }
                              } else if (_feedbackIndex != null && isCorrect) {
                                bgColor = const Color(0xFFF0FDF4).withOpacity(0.5);
                                borderColor = const Color(0xFF86EFAC); // border-green-300
                              }

                              return GestureDetector(
                                onTap: () => _handleSelect(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  transform: Matrix4.translationValues(0, offsetY, 0),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: borderColor, width: isSelected ? 3 : 1),
                                    boxShadow: isSelected
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.06),
                                              blurRadius: shadowBlur,
                                              offset: const Offset(0, 8),
                                            ),
                                            const BoxShadow(
                                              color: Color(0xFFE2E8F0),
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Transform.rotate(
                                    angle: item.rotation * pi / 180,
                                    child: _buildShape(item.shape, index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        if (_feedbackIndex != null) ...[
                          const SizedBox(height: 48),
                          _items[_feedbackIndex!].isOdd
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.emoji_events, color: Color(0xFF16A34A)), // text-green-600
                                    const SizedBox(width: 8),
                                    Text(
                                      'Great Vision!',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF16A34A), // text-green-600
                                      ),
                                    ),
                                  ],
                                ).animate().fadeIn().slideY(begin: -0.2, end: 0)
                              : Text(
                                  'There it is. Keep going!',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF64748B), // text-slate-500
                                  ),
                                ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHudChip({
    required IconData icon,
    required String text,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF334155), // text-slate-700
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShape(String shape, int index) {
    // Using Icons as SVG replacement for simplicity while maintaining visual fidelity
    IconData iconData;
    switch (shape) {
      case 'triangle':
        iconData = CupertinoIcons.triangle_fill;
        break;
      case 'square':
        iconData = CupertinoIcons.square_fill;
        break;
      case 'circle':
        iconData = CupertinoIcons.circle_fill;
        break;
      case 'diamond':
        iconData = CupertinoIcons.rhombus_fill;
        break;
      default:
        iconData = CupertinoIcons.square_fill;
    }

    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Color(0xFF4F46E5), Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(
        iconData,
        size: 64,
        color: Colors.white,
      ),
    );
  }
}

class _PatternItem {
  final int id;
  final String shape;
  final bool isOdd;
  final double rotation;

  _PatternItem({
    required this.id,
    required this.shape,
    required this.isOdd,
    required this.rotation,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// WORD ASSOCIATION
// ═══════════════════════════════════════════════════════════════════════════

class _WordAssociationView extends StatefulWidget {
  final VoidCallback onComplete;

  const _WordAssociationView({required this.onComplete});

  @override
  State<_WordAssociationView> createState() => _WordAssociationViewState();
}

class _WordAssociationViewState extends State<_WordAssociationView> {
  static const List<Map<String, dynamic>> _baseWords = [
    {'word': 'Morning', 'theme': Color(0xFFFFF9F2)},
    {'word': 'Garden', 'theme': Color(0xFFF2F9F2)},
    {'word': 'Summer', 'theme': Color(0xFFFFFBF0)},
    {'word': 'Friendship', 'theme': Color(0xFFFFF2F6)},
    {'word': 'Music', 'theme': Color(0xFFF2F2FF)},
    {'word': 'Travel', 'theme': Color(0xFFF2F9FF)},
  ];

  late Map<String, dynamic> _currentBase;
  List<String> _options = [];
  bool _loading = true;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    final random = Random();
    _currentBase = _baseWords[random.nextInt(_baseWords.length)];
    
    // Simulate AI delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Mock AI response based on the word
    _options = _getMockAssociations(_currentBase['word']);
    
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  List<String> _getMockAssociations(String word) {
    switch (word) {
      case 'Morning': return ['Coffee', 'Sunrise', 'Quiet', 'Dew'];
      case 'Garden': return ['Flowers', 'Peace', 'Green', 'Growth'];
      case 'Summer': return ['Warmth', 'Beach', 'Ice Cream', 'Sun'];
      case 'Friendship': return ['Trust', 'Laughter', 'Support', 'Love'];
      case 'Music': return ['Melody', 'Dance', 'Rhythm', 'Song'];
      case 'Travel': return ['Adventure', 'New', 'Journey', 'Explore'];
      default: return ['Light', 'Hope', 'Calm', 'Joy'];
    }
  }

  void _handleSelect(String opt) {
    setState(() {
      _selected = opt;
    });
    Future.delayed(const Duration(milliseconds: 2500), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF292524), // stone-800
                backgroundColor: Color(0xFFE7E5E4), // stone-200
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'PREPARING EXERCISE...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFA8A29E), // text-stone-400
                letterSpacing: 1.2, // tracking-widest
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      color: _currentBase['theme'],
      width: double.infinity,
      child: Stack(
        children: [
          // Calm, Mostly Static Background
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ).animate().blur(begin: const Offset(120, 120), end: const Offset(120, 120)).fadeIn(duration: 1000.ms),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        'REFLECTION',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFA8A29E), // text-stone-400
                          letterSpacing: 3.6, // tracking-[0.3em]
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentBase['word'],
                        style: GoogleFonts.inter(
                          fontSize: 60, // md:text-7xl approx
                          fontWeight: FontWeight.w900, // Blocky & Bold
                          color: const Color(0xFF292524), // text-stone-800
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedOpacity(
                        opacity: _selected != null ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          'What word feels right to you?',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            color: const Color(0xFF78716C), // text-stone-500
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                  const SizedBox(height: 64),

                  // Anchored Choice Tiles
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448), // max-w-md
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: _options.map((opt) {
                        final isSelected = _selected == opt;
                        final isDimmed = _selected != null && !isSelected;

                        return GestureDetector(
                          onTap: _selected == null ? () => _handleSelect(opt) : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            width: 180, // approx half of max-w-md with gap
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF292524) : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: isSelected 
                                  ? const Color(0xFF292524) 
                                  : const Color(0xFFF5F5F4), // border-stone-100
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 25,
                                        offset: const Offset(0, 10),
                                      )
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      )
                                    ],
                            ),
                            transform: Matrix4.identity()
                              ..scale(isSelected ? 1.05 : (isDimmed ? 0.9 : 1.0)),
                            child: Center(
                              child: Text(
                                opt,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF292524),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 96,
                    child: _selected != null
                        ? Center(
                            child: Text(
                              '"A thoughtful connection."',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900, // Blocky & Bold
                                color: const Color(0xFF44403C), // text-stone-700
                              ),
                            ).animate().fadeIn(duration: 1000.ms),
                          )
                        : null,
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

// ═══════════════════════════════════════════════════════════════════════════
// EMOTIONAL REFLECTION
// ═══════════════════════════════════════════════════════════════════════════

class _EmotionalReflectionView extends StatefulWidget {
  final VoidCallback onComplete;

  const _EmotionalReflectionView({required this.onComplete});

  @override
  State<_EmotionalReflectionView> createState() => _EmotionalReflectionViewState();
}

class _EmotionalReflectionViewState extends State<_EmotionalReflectionView> {
  static const List<Map<String, dynamic>> _emotions = [
    {
      'label': 'At Peace',
      'icon': '🧘',
      'colors': [Color(0xFFFAFAF9), Color(0xFFECFDF5)], // stone-50 to emerald-50
    },
    {
      'label': 'Resting',
      'icon': '🍵',
      'colors': [Color(0xFFFAFAF9), Color(0xFFEEF2FF)], // stone-50 to indigo-50
    },
    {
      'label': 'Joyful',
      'icon': '🌸',
      'colors': [Color(0xFFFAFAF9), Color(0xFFFFF1F2)], // stone-50 to rose-50
    },
    {
      'label': 'Thoughtful',
      'icon': '📜',
      'colors': [Color(0xFFFAFAF9), Color(0xFFFFFBEB)], // stone-50 to amber-50
    },
  ];

  String? _selected;
  String? _reflection;
  bool _loading = false;
  List<Color> _bgGradient = [const Color(0xFFFAFAF9), const Color(0xFFF5F5F4)];

  Future<void> _handleSelect(String emotion) async {
    final emotionData = _emotions.firstWhere((e) => e['label'] == emotion);
    
    setState(() {
      _bgGradient = emotionData['colors'];
      _selected = emotion;
      _loading = true;
    });

    // Simulate AI
    await Future.delayed(const Duration(milliseconds: 2000));
    
    setState(() {
      _reflection = _getMockReflection(emotion);
      _loading = false;
    });
  }

  String _getMockReflection(String emotion) {
    switch (emotion) {
      case 'At Peace': return "Peace is a gentle strength. Let it settle in your heart.";
      case 'Resting': return "Rest is not idleness. It is the soil where energy grows.";
      case 'Joyful': return "Joy is the sunlight of the soul. Let it shine.";
      case 'Thoughtful': return "Your thoughts are like clouds, drifting and changing.";
      default: return "Take this moment for yourself.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedEmotionData = _selected != null 
        ? _emotions.firstWhere((e) => e['label'] == _selected) 
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selected == null) ...[
                Column(
                  children: [
                    Text(
                      'MORNING CHECK-IN',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900, // font-black
                        color: const Color(0xFFA8A29E), // text-stone-400
                        letterSpacing: 1.2, // tracking-widest
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How is your heart today?',
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w900, // Blocky & Bold
                        color: const Color(0xFF292524), // text-stone-800
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ).animate().fadeIn(duration: 1000.ms),

                const SizedBox(height: 64),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _emotions.map((e) => GestureDetector(
                      onTap: () => _handleSelect(e['label']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: const Color(0xFFF5F5F4), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(e['icon'], style: const TextStyle(fontSize: 48)),
                            const SizedBox(width: 32),
                            Text(
                              e['label'],
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900, // Blocky & Bold
                                color: const Color(0xFF44403C), // text-stone-700
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ] else ...[
                // Selected State
                Column(
                  children: [
                    Text(
                      selectedEmotionData!['icon'],
                      style: const TextStyle(fontSize: 120),
                    ).animate().fadeIn().scale(),
                    
                    const SizedBox(height: 48),

                    if (_loading)
                      Column(
                        children: [
                          const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: Color(0xFF292524),
                              backgroundColor: Color(0xFFE7E5E4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'LISTENING SOFTLY...',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA8A29E),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(48),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(48),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: Text(
                                  '"$_reflection"',
                                  style: GoogleFonts.inter(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900, // Blocky & Bold
                                    color: const Color(0xFF292524),
                                    height: 1.625,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ).animate().fadeIn().slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 48),

                          GestureDetector(
                            onTap: widget.onComplete,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF292524),
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Done & Breathe',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.chat_bubble, size: 16, color: Color(0xFFA8A29E)),
                              const SizedBox(width: 8),
                              Text(
                                'SAVE TO JOURNAL?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFA8A29E),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOCUS BREATHING
// ═══════════════════════════════════════════════════════════════════════════

class _FocusBreathingView extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const _FocusBreathingView({required this.onComplete, required this.onBack});

  @override
  State<_FocusBreathingView> createState() => _FocusBreathingViewState();
}

class _FocusBreathingViewState extends State<_FocusBreathingView> {
  int _cycle = 0;
  String _phase = 'Inhale...';
  bool _isExpanding = false;

  @override
  void initState() {
    super.initState();
    _runCycle();
  }

  Future<void> _runCycle() async {
    int currentCycle = 0;
    while (currentCycle < 3 && mounted) {
      setState(() {
        _phase = 'Inhale...';
        _isExpanding = true;
      });
      await Future.delayed(const Duration(milliseconds: 4000));
      if (!mounted) return;

      setState(() {
        _phase = 'Hold';
      });
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;

      setState(() {
        _phase = 'Exhale...';
        _isExpanding = false;
      });
      await Future.delayed(const Duration(milliseconds: 4000));
      if (!mounted) return;

      currentCycle++;
      setState(() {
        _cycle = currentCycle;
      });
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A), // bg-[#0f172a]
      child: Stack(
        children: [
          // Deep Atmospheric Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
          ),

          // Subliminal Light Beams
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2000.ms).blur(begin: const Offset(120, 120), end: const Offset(120, 120)),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 2000.ms, delay: 1000.ms).blur(begin: const Offset(120, 120), end: const Offset(120, 120)),
          ),

          // Subtle Exit Button
          Positioned(
            top: 24,
            right: 24,
            child: SafeArea(
              child: GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.transparent,
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white.withOpacity(0.3),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Multi-Layered "Lotus" Orb
                  SizedBox(
                    width: 320,
                    height: 320,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Bloom Circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 4000),
                          curve: Curves.easeInOut,
                          width: _isExpanding ? 320 : 160,
                          height: _isExpanding ? 320 : 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withOpacity(_isExpanding ? 0.4 : 0.0), // teal-400
                            shape: BoxShape.circle,
                          ),
                        ).animate().blur(begin: const Offset(20, 20), end: const Offset(20, 20)),

                        // Middle Glow Circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 4000),
                          curve: Curves.easeInOut,
                          width: _isExpanding ? 256 : 140,
                          height: _isExpanding ? 256 : 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA).withOpacity(_isExpanding ? 0.6 : 0.0), // blue-400
                            shape: BoxShape.circle,
                          ),
                        ).animate().blur(begin: const Offset(16, 16), end: const Offset(16, 16)),

                        // Core Breathing Orb
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 4000),
                          curve: Curves.easeInOut,
                          width: _isExpanding ? 160 : 80,
                          height: _isExpanding ? 160 : 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF60A5FA), Color(0xFF14B8A6)], // blue-400 to teal-500
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.4),
                                blurRadius: 60,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Fading Serif Typography
                  SizedBox(
                    height: 128,
                    child: Column(
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 1000),
                          opacity: _phase == 'Hold' ? 0.4 : 1.0,
                          child: Text(
                            _phase,
                            style: GoogleFonts.inter(
                              fontSize: 48,
                              fontWeight: FontWeight.w900, // Blocky & Bold
                              color: const Color(0xFFDBEAFE), // blue-100
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          'CYCLE ${min(_cycle + 1, 3)} OF 3',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF93C5FD).withOpacity(0.4), // blue-300/40
                            letterSpacing: 4.0, // tracking-[0.4em]
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [0, 1, 2].map((i) {
                            final isActive = i <= _cycle;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 700),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 4,
                              width: isActive ? 32 : 8,
                              decoration: BoxDecoration(
                                color: isActive 
                                  ? const Color(0xFF60A5FA) // blue-400
                                  : const Color(0xFF1E3A8A).withOpacity(0.5), // blue-900/50
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
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

