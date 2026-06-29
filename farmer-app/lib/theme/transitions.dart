import 'package:flutter/material.dart';

/// Shared page transitions for MangoMind.
///
/// Use [appRoute] anywhere you'd normally write `MaterialPageRoute(...)`. It
/// gives every pushed screen a consistent fade-through + gentle scale motion
/// (Material's recommended transition for navigating between unrelated pages),
/// instead of the platform default. Keeping it in one place means the whole app
/// shares the same feel and timing.
///
/// Example:
/// ```dart
/// Navigator.push(context, appRoute(const AddFarmPage()));
/// ```
Route<T> appRoute<T>(
  Widget page, {
  Duration duration = const Duration(milliseconds: 350),
}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _FadeThrough(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Fade-through: the incoming page fades in while scaling up subtly from 96%,
/// and the outgoing page fades out. Curves are eased so it feels smooth rather
/// than linear.
class _FadeThrough extends StatelessWidget {
  const _FadeThrough({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );
    final scaleIn = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    // While a new page covers this one, fade the old page out slightly.
    final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
      ),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      ),
    );
  }
}
