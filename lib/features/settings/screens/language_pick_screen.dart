import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/language_helper.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../providers/settings_provider.dart';

class LanguagePickScreen extends ConsumerWidget {
  const LanguagePickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final settings = ref.read(settingsControllerProvider);
    final canPop = Navigator.canPop(context);

    Widget languageTile(String code, String shortLabel, String title, String nativeName) {
      final isSelected = lang == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ScaleOnPress(
          onTap: () => settings.setLanguage(code),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Highlight indicator strip on left edge
                if (isSelected)
                  Container(
                    width: 3,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 3),
                const SizedBox(width: 16),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentSoft : AppColors.bgSecondary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shortLabel,
                    style: AppTextStyles.small.copyWith(
                      color: isSelected ? AppColors.accent : AppColors.inkMid,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  nativeName,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.inkMid,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top 40% — Stylized geometric parchment/terracotta art representation
            Expanded(
              flex: 4,
              child: Container(
                color: AppColors.bgPrimary,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderStrong, width: 2),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Stylized book and soundwaves
                            Icon(
                              Icons.menu_book_rounded,
                              size: 72,
                              color: AppColors.accent,
                            ),
                            Positioned(
                              bottom: 24,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  5,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    width: 4,
                                    height: (index == 2 ? 24.0 : (index % 2 == 0 ? 12.0 : 18.0)),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGlow,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (canPop)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 20,
                        child: ScaleOnPress(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Bottom 60% — White rounded top sheet container
            Expanded(
              flex: 6,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0C000000),
                      offset: Offset(0, -4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('language_pick_title', lang),
                      style: AppTextStyles.h1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ቋንቋዎን ይምረጡ • Afaan filadhu',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkMid,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          languageTile(kLangEnglish, 'EN', 'English', 'English'),
                          languageTile(kLangAmharic, 'አማ', 'አማርኛ', 'Amharic'),
                          languageTile(kLangOromo, 'ORO', 'Afaan Oromo', 'Oromiffa'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TemariButton(
                      label: canPop ? 'Done' : 'Next',
                      onPressed: () {
                        if (canPop) {
                          context.pop();
                        } else {
                          // Progress to Onboarding Screen slides
                          context.go('/onboarding');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
