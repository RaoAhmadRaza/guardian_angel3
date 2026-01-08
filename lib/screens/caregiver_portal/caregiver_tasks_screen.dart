import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class CaregiverTasksScreen extends StatefulWidget {
  const CaregiverTasksScreen({super.key});

  @override
  State<CaregiverTasksScreen> createState() => _CaregiverTasksScreenState();
}

class _CaregiverTasksScreenState extends State<CaregiverTasksScreen> {
  String _activeTab = 'Pending';

  final List<Map<String, dynamic>> _tasks = [
    {'id': '1', 'title': 'Upload Blood Lab Results', 'time': 'By 5:00 PM', 'status': 'Pending', 'type': 'Report'},
    {'id': '2', 'title': 'Schedule Eye Appointment', 'time': 'This Week', 'status': 'Pending', 'type': 'Appointment'},
    {'id': '3', 'title': 'Refill Heart Medication', 'time': 'Tomorrow', 'status': 'Pending', 'type': 'Medication'},
    {'id': '4', 'title': 'Morning Walk recorded', 'time': 'Done', 'status': 'Completed', 'type': 'Activity'},
    {'id': '5', 'title': 'Weekly weight log', 'time': 'Done', 'status': 'Completed', 'type': 'Health'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _tasks.where((t) => t['status'] == _activeTab).toList();
    final pendingCount = _tasks.where((t) => t['status'] == 'Pending').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasks',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pendingCount actions required',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.add, color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Custom Segmented Control
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedAlign(
                          alignment: _activeTab == 'Pending' ? Alignment.centerLeft : Alignment.centerRight,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: Container(
                            width: (constraints.maxWidth - 8) / 2,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 'Pending'),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Text(
                                    'Pending',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _activeTab == 'Pending' ? Colors.black : const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _activeTab = 'Completed'),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Text(
                                    'Completed',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _activeTab == 'Completed' ? Colors.black : const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              if (filteredTasks.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTasks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return _buildTaskCard(task);
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.check_mark_circled_solid, size: 40, color: Color(0xFFE5E5EA)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ALL CAUGHT UP!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8E8E93),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final isCompleted = _activeTab == 'Completed';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFE5F1FF), // emerald-50 vs blue-50
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: isCompleted ? const Color(0xFF34C759) : const Color(0xFF007AFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'],
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? const Color(0xFFC7C7CC) : Colors.black,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      (task['type'] as String).toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF8E8E93),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E5EA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task['time'],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.chevron_right, color: Color(0xFFC7C7CC), size: 18),
        ],
      ),
    );
  }
}
