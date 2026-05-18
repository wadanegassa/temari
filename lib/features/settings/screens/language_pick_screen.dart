import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/language_helper.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../settings/providers/settings_provider.dart';

class LanguagePickScreen extends ConsumerWidget {
  const LanguagePickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final settings = ref.read(settingsControllerProvider);

    Widget tile(String code, String title, String subtitle) {
      final selected = lang == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => settings.setLanguage(code),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.h3),
                        const SizedBox(height: 4),
                        Text(subtitle, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('language_pick_title', lang),
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 24),
              tile(kLangEnglish, 'English', 'Study in English'),
              tile(kLangAmharic, 'አማርኛ', 'Amharic'),
              tile(kLangOromo, 'Afaan Oromo', 'Oromiffa'),
              const Spacer(),
              TemariButton(
                label: AppStrings.get('next', lang),
                onPressed: () => context.go('/auth'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
