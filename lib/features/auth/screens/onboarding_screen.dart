import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../settings/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);

    final List<_OnboardingSlideData> slides = [
      _OnboardingSlideData(
        icon: Icons.mic_none_outlined,
        title: AppStrings.get('onboarding_1_title', lang),
        body: AppStrings.get('onboarding_1_body', lang),
      ),
      _OnboardingSlideData(
        icon: Icons.style_outlined,
        title: AppStrings.get('onboarding_2_title', lang),
        body: AppStrings.get('onboarding_2_body', lang),
      ),
      _OnboardingSlideData(
        icon: Icons.wifi_off_outlined,
        title: AppStrings.get('onboarding_3_title', lang),
        body: AppStrings.get('onboarding_3_body', lang),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav skip action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: ScaleOnPress(
                  onTap: () => context.go('/chatbot'),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      AppStrings.get('skip', lang),
                      style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMid,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Sliders area
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return _SlideWidget(
                    icon: slide.icon,
                    title: slide.title,
                    body: slide.body,
                  );
                },
              ),
            ),
            // Dots progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: _currentIndex == index ? 24.0 : 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? AppColors.accent : AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Bottom Action
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 32.0),
              child: TemariButton(
                label: _currentIndex < slides.length - 1
                    ? '${AppStrings.get('next', lang)} →'
                    : AppStrings.get('get_started', lang),
                onPressed: () {
                  if (_currentIndex < slides.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    context.go('/chatbot');
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

class _OnboardingSlideData {
  _OnboardingSlideData({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

class _SlideWidget extends StatelessWidget {
  const _SlideWidget({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Styled geometric abstract box
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 64,
                  color: AppColors.accent,
                ),
                // Small waves or details
                if (icon == Icons.mic_none_outlined)
                  Positioned(
                    right: 28,
                    top: 28,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGlow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: AppTextStyles.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: AppTextStyles.body.copyWith(
              color: AppColors.inkMid,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
