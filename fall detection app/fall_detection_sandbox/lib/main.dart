import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FallTestApp());
}

class FallTestApp extends StatelessWidget {
  const FallTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Fall Detection Test',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
