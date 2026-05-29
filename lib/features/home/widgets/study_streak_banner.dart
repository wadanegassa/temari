import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/user_stats_provider.dart';

class StudyStreakBanner extends ConsumerWidget {
  const StudyStreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final stats = ref.watch(userStatsProvider);
    
    final streak = stats.streak;
    final xp = stats.xp;

    final text = lang == 'am'
        ? "🔥 $streak-ቀን ቅደም ተከተል • $xp XP"
        : (lang == 'om'
            ? "🔥 Guyyaa $streak • $xp XP"
            : "🔥 $streak-day streak • $xp XP");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accent, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
