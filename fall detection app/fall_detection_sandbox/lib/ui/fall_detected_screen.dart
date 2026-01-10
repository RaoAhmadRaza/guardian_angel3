import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'simulated_sos_screen.dart';

class FallDetectedScreen extends StatefulWidget {
  const FallDetectedScreen({super.key});

  @override
  State<FallDetectedScreen> createState() => _FallDetectedScreenState();
}

class _FallDetectedScreenState extends State<FallDetectedScreen> {
  int _countdown = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        _timer?.cancel();
        _triggerSOS();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _triggerSOS() {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: (context) => const SimulatedSOSScreen()),
    );
  }

  void _cancelAlert() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFF9500), // System Orange
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Main Text
              const Text(
                'We detected a\npossible fall.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Are you okay?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              
              const Spacer(),
              
              // Countdown
              Text(
                'Sending test alert in $_countdown seconds',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // I'M OK Button
              SizedBox(
                width: double.infinity,
                height: 72,
                child: CupertinoButton(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  onPressed: _cancelAlert,
                  child: const Text(
                    "I'M OK",
                    style: TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                "Move or tap 'I'm OK' to cancel",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}