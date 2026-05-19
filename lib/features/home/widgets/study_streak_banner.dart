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
    
    // Simple mock calculation or reading from sessions
    final streak = sessions.isEmpty ? 1 : sessions.length.clamp(1, 99);

    final text = lang == 'am'
        ? "🔥 $streak-ቀን ቅደም ተከተል — ቀጥልበት!"
        : (lang == 'om'
            ? "🔥 Guyyaa $streak walitti aansee — itti fufi!"
            : "🔥 $streak-day streak — keep it up!");

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
