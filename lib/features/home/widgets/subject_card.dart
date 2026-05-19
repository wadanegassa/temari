import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_helper.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/scale_on_press.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({
    super.key,
    required this.subject,
    required this.noteCount,
    required this.onTap,
    this.accuracy,
  });

  final Subject subject;
  final int noteCount;
  final VoidCallback onTap;
  final double? accuracy;

  Color get _color {
    try {
      final colorHexVal = subject.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$colorHexVal', radix: 16));
    } catch (_) {
      // Fallback subject color matching index
      final i = subject.name.hashCode.abs() % AppColors.subjectColors.length;
      return AppColors.subjectColors[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = accuracy ?? 0.74; // Default mockup accuracy or dynamic
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-left color dot
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            // Subject Name
            Text(
              subject.name,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Notes count
            Text(
              '$noteCount notes',
              style: AppTextStyles.small.copyWith(
                color: AppColors.inkLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Bottom row: thin 4px progress bar + relative time stamp
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: acc.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Last: ${formatRelative(subject.lastStudiedAt ?? subject.updatedAt)}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.inkLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
