import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../settings/providers/settings_provider.dart';

class StudyStreakBanner extends ConsumerWidget {
  const StudyStreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final sessions = ref.watch(hiveServiceProvider).sessions;
    final streak = sessions.isEmpty ? 1 : sessions.length.clamp(1, 99);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_outlined,
                color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('streak', lang),
                  style: AppTextStyles.label,
                ),
                Text(
                  '$streak ${lang == 'en' ? 'days' : ''}',
                  style: AppTextStyles.h3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
