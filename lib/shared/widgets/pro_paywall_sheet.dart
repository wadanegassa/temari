import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'scale_on_press.dart';
import 'temari_button.dart';

class ProPaywallSheet extends ConsumerStatefulWidget {
  const ProPaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProPaywallSheet(),
    );
  }

  @override
  ConsumerState<ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends ConsumerState<ProPaywallSheet> {
  bool _isUpgrading = false;
  bool _upgradeSuccess = false;

  Future<void> _upgrade() async {
    setState(() => _isUpgrading = true);
    // Simulate minor premium network transaction delay
    await Future.delayed(const Duration(milliseconds: 1400));
    
    await ref.read(settingsControllerProvider).setPro(true);
    HapticFeedback.heavyImpact();
    
    setState(() {
      _isUpgrading = false;
      _upgradeSuccess = true;
    });

    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_upgradeSuccess) {
      return Container(
        height: 480,
        decoration: const BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Temari Pro!',
                style: AppTextStyles.h1.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'All features have been successfully unlocked.',
                style: AppTextStyles.body.copyWith(color: AppColors.inkLight),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Text(
                'Unlock Temari Pro',
                style: AppTextStyles.display.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LIFETIME',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Invest in your academic success. Pay once, own forever.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.inkLight,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Features bullet points
          _FeatureRow(
            icon: Icons.upload_file_outlined,
            title: 'Multimodal Uploads',
            description: 'Transcribe voice, snap books, or upload complete PDF files.',
          ),
          const SizedBox(height: 20),
          _FeatureRow(
            icon: Icons.hub_outlined,
            title: 'Interactive Mind Maps',
            description: 'Generate and navigate beautiful, dynamic mind map structures.',
          ),
          const SizedBox(height: 20),
          _FeatureRow(
            icon: Icons.bar_chart_outlined,
            title: 'Learning Analytics',
            description: 'Monitor daily streak histories, subjects performance and metrics.',
          ),
          const SizedBox(height: 20),
          _FeatureRow(
            icon: Icons.all_inclusive,
            title: 'Unlimited Access',
            description: 'Create unlimited notes, subjects, and study flashcards.',
          ),
          const SizedBox(height: 36),

          // Action buttons
          if (_isUpgrading)
            const SizedBox(
              height: 52,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else
            TemariButton(
              label: 'Upgrade Lifetime — \$2.99 / 150 ETB',
              onPressed: _upgrade,
            ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleOnPress(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _upgrade();
                },
                child: Text(
                  'Restore Purchases',
                  style: AppTextStyles.small.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Text(
                'TOS & Privacy',
                style: AppTextStyles.small.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.inkLight,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
