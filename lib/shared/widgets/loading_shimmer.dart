import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({super.key, this.lines = 3});

  final int lines;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(widget.lines, (i) {
            final delay = i * 0.12;
            final v = ((t + delay) % 1.0);
            final opacity = 0.25 + (0.35 * (1 - (v - 0.5).abs() * 2));
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
