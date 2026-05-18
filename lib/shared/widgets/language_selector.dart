import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/language_helper.dart';
import '../../features/settings/providers/settings_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final ctrl = ref.read(settingsControllerProvider);
    Widget chip(String code, String label) {
      final sel = lang == code;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => ctrl.setLanguage(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: sel ? Colors.white : AppColors.textPrimary,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(kLangEnglish, 'EN'),
        chip(kLangAmharic, 'አማ'),
        chip(kLangOromo, 'OM'),
      ],
    );
  }
}
