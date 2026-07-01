import 'package:flutter/material.dart';

/// Small touch micro-interactions for MangoMind.
///
/// [Pressable] wraps any widget and gives it a subtle "press" feel: the child
/// scales down slightly while a finger is held on it, then springs back on
/// release. Use it on custom tap targets (feature cards, list cards, image
/// buttons) that don't already get Material ink feedback, so taps feel
/// responsive and tactile.
///
/// Example:
/// ```dart
/// Pressable(
///   onTap: () => openThing(),
///   child: MyCard(...),
/// );
/// ```
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 110),
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far to shrink while pressed (1.0 = no shrink).
  final double scale;

  /// How long the scale animation takes in each direction.
  final Duration duration;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
