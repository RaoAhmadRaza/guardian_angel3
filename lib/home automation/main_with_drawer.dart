import 'package:flutter/material.dart';
import 'navigation/drawer_wrapper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Automation with Drawer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      // Wrap your existing HomeAutomationScreen with DrawerWrapper
      home: const DrawerWrapper(
        homeScreen: HomeAutomationScreen(), // Your existing screen from main.dart
      ),
    );
  }
}

// This would be your existing HomeAutomationScreen from main.dart
// For demonstration purposes, here's a placeholder
class HomeAutomationScreen extends StatelessWidget {
  const HomeAutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Home Automation Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your existing home automation UI goes here',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tap the menu icon in the top-left to open the drawer',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
