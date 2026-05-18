import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class TemariButton extends StatelessWidget {
  const TemariButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TemariButtonVariant.primary,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TemariButtonVariant variant;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bg = variant == TemariButtonVariant.primary
        ? AppColors.primary
        : AppColors.surface;
    final fg = variant == TemariButtonVariant.primary
        ? Colors.white
        : AppColors.primary;
    final border = variant == TemariButtonVariant.secondary
        ? Border.all(color: AppColors.border)
        : null;
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

enum TemariButtonVariant { primary, secondary }
