import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'side_menu.dart';
import '../screens/rooms_screen.dart';

class DrawerWrapper extends StatefulWidget {
  final Widget homeScreen;

  const DrawerWrapper({
    super.key,
    required this.homeScreen,
  });

  @override
  State<DrawerWrapper> createState() => DrawerWrapperState();

  // Static method to access the drawer state from anywhere in the widget tree
  static DrawerWrapperState? of(BuildContext context) {
    return context.findAncestorStateOfType<DrawerWrapperState>();
  }
}

class DrawerWrapperState extends State<DrawerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> animation;
  late Animation<double> scaleAnimation;
  
  // Current selected screen
  String _selectedScreen = 'home';
  
  Widget get currentScreen {
    switch (_selectedScreen) {
      case 'rooms':
        return const RoomsScreen();
      case 'home':
      default:
        return widget.homeScreen;
    }
  }  bool get isDrawerOpen => _animationController.isCompleted;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        // Update status bar color based on animation progress
        if (animation.value > 0.5) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
        } else {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
        }
      });

    animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleDrawer() {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 239, 243),
      body: Stack(
        children: [
          // Side Menu (behind) with Fade Effect
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return FadeTransition(
                opacity: animation,
                child: RepaintBoundary(
                  child: SideMenu(
                    onMenuSelected: (menuId) {
                      // Auto-close drawer when menu item is selected
                      toggleDrawer();
                      
                      // Change screen based on menu selection
                      setState(() {
                        _selectedScreen = menuId;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          // Animated Main Content with Scale and Transform
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(30 * animation.value * pi / 180)
                    ..translate(265 * animation.value),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      24 * animation.value,
                    ),
                    child: RepaintBoundary(
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: currentScreen,
          ),
          // Menu Button (top-left) - Hidden, using the one in header instead
          // AnimatedBuilder(
          //   animation: animation,
          //   builder: (context, child) {
          //     return SafeArea(
          //       child: Padding(
          //         padding: EdgeInsets.only(
          //           left: 24 + (241 * animation.value),
          //           top: 14,
          //         ),
          //         child: GestureDetector(
          //           onTap: toggleDrawer,
          //           child: Container(
          //             width: 48,
          //             height: 48,
          //             decoration: BoxDecoration(
          //               color: Colors.transparent,
          //               borderRadius: BorderRadius.circular(12),
          //             ),
          //             child: SizedBox(
          //               width: 36,
          //               height: 36,
          //               child: RiveAnimation.asset(
          //                 'assets/RiveAssets/menu_button.riv',
          //                 stateMachines: const ['State Machine 1'],
          //                 onInit: _onRiveInit,
          //               ),
          //             ),
          //           ),
          //         ),
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }
}
