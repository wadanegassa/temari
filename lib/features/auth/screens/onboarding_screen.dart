import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../settings/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/language'),
                child: Text(
                  AppStrings.get('skip', ref.watch(languageProvider)),
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (v) => setState(() => _i = v),
                children: const [
                  _Slide(
                    icon: Icons.school_outlined,
                    titleKey: 'onboarding_1_title',
                    bodyKey: 'onboarding_1_body',
                  ),
                  _Slide(
                    icon: Icons.translate_outlined,
                    titleKey: 'onboarding_2_title',
                    bodyKey: 'onboarding_2_body',
                  ),
                  _Slide(
                    icon: Icons.wifi_off_outlined,
                    titleKey: 'onboarding_3_title',
                    bodyKey: 'onboarding_3_body',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _i == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _i == i ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: TemariButton(
                label: _i < 2
                    ? AppStrings.get('next', ref.watch(languageProvider))
                    : AppStrings.get('get_started', ref.watch(languageProvider)),
                onPressed: () {
                  if (_i < 2) {
                    _page.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    context.go('/language');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends ConsumerWidget {
  const _Slide({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
  });

  final IconData icon;
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 56, color: AppColors.accent),
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.get(titleKey, lang),
            style: AppTextStyles.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.get(bodyKey, lang),
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
