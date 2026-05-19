import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScaleOnPress extends StatefulWidget {
  const ScaleOnPress({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

class _ScaleOnPressState extends State<ScaleOnPress> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _isPressed = false);
              if (widget.haptic) {
                HapticFeedback.lightImpact();
              }
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
