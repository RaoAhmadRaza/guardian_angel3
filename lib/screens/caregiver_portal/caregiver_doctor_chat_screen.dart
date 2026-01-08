import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class CaregiverDoctorChatScreen extends StatefulWidget {
  const CaregiverDoctorChatScreen({super.key});

  @override
  State<CaregiverDoctorChatScreen> createState() => _CaregiverDoctorChatScreenState();
}

class _CaregiverDoctorChatScreenState extends State<CaregiverDoctorChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'id': '1', 'sender': 'Doctor', 'text': "Hello, I've reviewed the latest vitals for Eleanor. The HRV is showing a positive trend.", 'timestamp': "Yesterday"},
    {'id': '2', 'sender': 'Caregiver', 'text': "That's great news, Dr. Thorne. Should we adjust her walking schedule?", 'timestamp': "Yesterday"},
    {'id': '3', 'sender': 'Doctor', 'text': "Let's keep it as is for another week. I'll send over the formal report shortly.", 'timestamp': "9:30 AM"},
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'id': DateTime.now().toString(),
        'sender': 'Caregiver',
        'text': _controller.text,
        'timestamp': 'Now',
      });
    });
    _controller.clear();

    // Simulate reply
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'id': DateTime.now().toString(),
            'sender': 'Doctor',
            'text': "I've just uploaded the Q3 Cardiac Screening report to the Reports section. Please review when you can.",
            'timestamp': 'Now',
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left, color: Color(0xFFFF2D55), size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(CupertinoIcons.heart_circle_fill, color: Color(0xFFFF2D55), size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. Aris Thorne',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'CARDIOLOGIST',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8E8E93),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.phone_fill, color: Color(0xFFFF2D55)),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(CupertinoIcons.videocam_fill, color: const Color(0xFFFF2D55)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF2F2F7), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC), // slate-50/30
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Disclaimer Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFFF2D55), size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professional Consultation',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF881337), // rose-900
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This channel is strictly for medical consultation. For technical support, please contact Guardian AI.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFBE123C).withOpacity(0.7), // rose-700
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  ..._messages.map((msg) {
                    final isMe = msg['sender'] == 'Caregiver';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.black : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: isMe ? null : Border.all(color: Colors.black.withOpacity(0.05)),
                                  ),
                                  child: Text(
                                    msg['text'],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: isMe ? Colors.white : Colors.black,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      msg['timestamp'],
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF8E8E93),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(CupertinoIcons.check_mark, size: 12, color: Colors.black),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: const Color(0xFFF2F2F7))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.add, color: Color(0xFFFF2D55)),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: GoogleFonts.inter(color: const Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: Color(0xFFFF2D55), size: 32),
                    onPressed: _sendMessage,
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
