import 'package:flutter/material.dart';
import 'package:guardian_onboarding/guardian_onboarding.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const OnboardingDemo(),
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
    );
  }
}

class OnboardingDemo extends StatelessWidget {
  const OnboardingDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      OnboardingPageData.fromNetwork(
        title: 'Welcome',
        description: 'Reusable onboarding for your Flutter apps',
        url: 'https://picsum.photos/seed/1/800/600',
      ),
      OnboardingPageData.fromNetwork(
        title: 'Beautiful',
        description: 'Animations and simple API',
        url: 'https://picsum.photos/seed/2/800/600',
      ),
      OnboardingPageData.fromNetwork(
        title: 'Ready?',
        description: 'Let\'s get started',
        url: 'https://picsum.photos/seed/3/800/600',
        buttonText: 'Get Started',
      ),
    ];

    return OnboardingFlow(
      pages: pages,
      onCompleted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DoneScreen()),
        );
      },
    );
  }
}

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text('Onboarding Complete!'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OnboardingDemo()),
              ),
              child: const Text('Restart'),
            )
          ],
        ),
      ),
    );
  }
}
