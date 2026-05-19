import 'dart:math' show pi;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({
    super.key,
    required this.question,
    required this.answer,
    required this.onFlipped,
  });

  final String question;
  final String answer;
  final ValueChanged<bool> onFlipped;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  bool _isFlipped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isFlipped) {
      _controller.reverse();
      _isFlipped = false;
    } else {
      _controller.forward();
      _isFlipped = true;
    }
    widget.onFlipped(_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        return GestureDetector(
          onTap: _handleTap,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective depth
              ..rotateY(angle),
            child: angle < pi / 2
                ? _buildFrontCard()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBackCard(),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Text(
            'QUESTION',
            style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
          ),
          const Spacer(),
          Text(
            widget.question,
            style: AppTextStyles.h2.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.inkLight),
              const SizedBox(width: 6),
              Text(
                'Tap card to flip →',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.inkLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Text(
            'ANSWER',
            style: AppTextStyles.label.copyWith(color: AppColors.accent),
          ),
          const Spacer(),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              widget.answer,
              style: AppTextStyles.body.copyWith(
                color: AppColors.ink,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          Text(
            'Tap again to see question',
            style: AppTextStyles.small.copyWith(
              color: AppColors.accent.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
