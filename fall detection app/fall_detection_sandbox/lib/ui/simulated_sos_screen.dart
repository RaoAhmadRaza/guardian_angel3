import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'logs_screen.dart';

class SimulatedSOSScreen extends StatelessWidget {
  const SimulatedSOSScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemRed,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Alert Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.bell_fill,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Header
              const Text(
                '🚨 TEST ALERT\nTRIGGERED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Explanation
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text(
                      'In the real app, this would notify caregivers with your location.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No real alert was sent.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Reset Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CupertinoButton(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.refresh, color: CupertinoColors.systemRed),
                      SizedBox(width: 8),
                      Text(
                        'Reset Test',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Logs Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CupertinoButton(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (context) => const LogsScreen()),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.graph_square, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'View Logs',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
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