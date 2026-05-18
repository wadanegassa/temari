import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({
    super.key,
    required this.question,
    required this.answer,
    required this.onResult,
  });

  final String question;
  final String answer;
  final void Function(int result) onResult;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  var _flipped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (!_flipped) {
      _controller.forward();
      _flipped = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: angle < pi / 2
              ? GestureDetector(
                  onTap: _flip,
                  child: _card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Question', style: AppTextStyles.label),
                        const SizedBox(height: 16),
                        Text(
                          widget.question,
                          style: AppTextStyles.h3,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text('Tap to reveal', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _card(
                    color: AppColors.accentSoft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Answer', style: AppTextStyles.label),
                        const SizedBox(height: 16),
                        Text(
                          widget.answer,
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _btn('Missed', AppColors.error, 0),
                            _btn('Almost', AppColors.warning, 1),
                            _btn('Got it', AppColors.success, 2),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _btn(String t, Color c, int r) {
    return TextButton(
      onPressed: () => widget.onResult(r),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card({required Widget child, Color color = AppColors.surface}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
