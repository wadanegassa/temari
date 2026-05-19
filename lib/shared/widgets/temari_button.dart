import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'scale_on_press.dart';

enum TemariButtonVariant { primary, secondary, ghost }

class TemariButton extends StatelessWidget {
  const TemariButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TemariButtonVariant.primary,
    this.expanded = true,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final TemariButtonVariant variant;
  final bool expanded;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    switch (variant) {
      case TemariButtonVariant.primary:
        bg = color ?? AppColors.accent;
        fg = Colors.white;
        border = null;
        break;
      case TemariButtonVariant.secondary:
        bg = Colors.transparent;
        fg = color ?? AppColors.accent;
        border = Border.all(color: AppColors.border, width: 1.5);
        break;
      case TemariButtonVariant.ghost:
        bg = Colors.transparent;
        fg = color ?? AppColors.inkMid;
        border = null;
        break;
    }

    final buttonWidget = Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.btnText.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final child = ScaleOnPress(
      onTap: onPressed,
      child: buttonWidget,
    );

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: child,
      );
    }
    return child;
  }
}
