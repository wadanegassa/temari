import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_helper.dart';
import '../../../shared/models/note.dart';

class RecentNoteTile extends StatelessWidget {
  const RecentNoteTile({
    super.key,
    required this.note,
    required this.subjectName,
    required this.onTap,
  });

  final Note note;
  final String subjectName;
  final VoidCallback onTap;

  IconData _icon() {
    switch (note.type) {
      case 'voice':
        return Icons.mic_none_rounded;
      case 'photo':
        return Icons.image_outlined;
      case 'file':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon(), color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: AppTextStyles.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (subjectName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                subjectName,
                                style: AppTextStyles.label
                                    .copyWith(color: AppColors.accent, fontSize: 11),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            formatRelative(note.updatedAt),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
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
