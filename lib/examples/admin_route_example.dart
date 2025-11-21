import 'package:flutter/material.dart';
import '../ui/dev/admin_debug_route.dart';

/// Example app integration showing how to register admin route.
/// 
/// Add this route to your MaterialApp:
/// ```dart
/// MaterialApp(
///   routes: {
///     '/admin': (context) => const AdminDebugRoute(),
///   },
/// )
/// ```
/// 
/// Or use onGenerateRoute for more control:
/// ```dart
/// MaterialApp(
///   onGenerateRoute: (settings) {
///     if (settings.name == '/admin') {
///       return MaterialPageRoute(
///         builder: (_) => const AdminDebugRoute(),
///       );
///     }
///     return null;
///   },
/// )
/// ```
class ExampleAppWithAdminRoute extends StatelessWidget {
  const ExampleAppWithAdminRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian Angel',
      routes: {
        '/': (context) => const HomePage(),
        '/admin': (context) => const AdminDebugRoute(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamed('/admin'),
          child: const Text('Open Admin UI'),
        ),
      ),
    );
  }
}
