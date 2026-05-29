import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_helper.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/scale_on_press.dart';

class RecentNoteTile extends StatelessWidget {
  const RecentNoteTile({
    super.key,
    required this.note,
    required this.subjectName,
    required this.onTap,
    this.onDelete,
    this.subjectColor,
  });

  final Note note;
  final String subjectName;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final Color? subjectColor;

  IconData _icon() {
    switch (note.type) {
      case 'voice':
        return Icons.mic_none_rounded;
      case 'photo':
        return Icons.photo_camera_outlined;
      case 'file':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  Color get _color {
    if (subjectColor != null) return subjectColor!;
    final i = subjectName.hashCode.abs() % AppColors.subjectColors.length;
    return AppColors.subjectColors[i];
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = formatRelative(note.updatedAt);
    final summary = note.aiSummary ?? note.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ScaleOnPress(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon Circle (36px)
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.bgSecondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(),
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              // Content: Title + Summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Untitled Note' : note.title,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.isEmpty ? 'No content' : summary,
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkMid,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right side: Timestamp + Subject Color Dot
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.inkLight,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
