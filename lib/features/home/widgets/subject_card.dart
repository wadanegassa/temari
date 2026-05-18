import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_helper.dart';
import '../../../shared/models/subject.dart';

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

  Color get _stripe {
    final i = subject.colorHex.hashCode.abs() % AppColors.subjectColors.length;
    return AppColors.subjectColors[i];
  }

  @override
  Widget build(BuildContext context) {
    final acc = accuracy ?? 0.0;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: _stripe,
                    borderRadius:
                        const BorderRadius.horizontal(left: Radius.circular(15)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject.name, style: AppTextStyles.h3, maxLines: 2),
                        const SizedBox(height: 6),
                        Text(
                          '$noteCount notes · ${formatRelative(subject.lastStudiedAt ?? subject.updatedAt)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                value: acc.clamp(0.0, 1.0),
                                strokeWidth: 3,
                                backgroundColor: AppColors.surfaceAlt,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(acc * 100).round()}%',
                              style: AppTextStyles.label,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
