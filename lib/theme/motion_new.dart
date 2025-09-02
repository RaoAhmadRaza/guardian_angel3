import 'package:flutter/material.dart';

/// Motion design system for Guardian Angel app
///
/// Provides consistent animation curves, durations, and motion patterns
/// following Material Design motion principles.
class AppMotion {
  AppMotion._();

  // Animation Durations
  static const Duration ultraFast = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration ultraSlow = Duration(milliseconds: 800);

  // Page Transitions
  static const Duration pageTransition = Duration(milliseconds: 400);
  static const Duration modalTransition = Duration(milliseconds: 350);

  // Component Animations
  static const Duration buttonPress = Duration(milliseconds: 150);
  static const Duration fieldFocus = Duration(milliseconds: 300);
  static const Duration errorShow = Duration(milliseconds: 250);
  static const Duration loadingIndicator = Duration(milliseconds: 1500);

  // Animation Curves
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve decelerate = Curves.easeOut;
  static const Curve sharp = Curves.easeInCubic;
  static const Curve gentle = Curves.easeOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.fastOutSlowIn;

  // Stagger Delays
  static Duration staggerDelay(int index) =>
      Duration(milliseconds: index * 100);
  static Duration listItemDelay(int index) =>
      Duration(milliseconds: index * 50);

  // Page Route Transitions
  static PageRouteBuilder<T> slideTransition<T>({
    required Widget page,
    Offset begin = const Offset(1.0, 0.0),
    Duration duration = pageTransition,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: spring,
          )),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<T> fadeTransition<T>({
    required Widget page,
    Duration duration = pageTransition,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: standardCurve,
          ),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<T> scaleTransition<T>({
    required Widget page,
    Duration duration = modalTransition,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: spring,
          ),
          child: child,
        );
      },
    );
  }
}
