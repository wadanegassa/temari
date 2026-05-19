import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/pro_paywall_sheet.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _copyBackup(String json) {
    Clipboard.setData(ClipboardData(text: json));
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Backup JSON copied to clipboard! 📋',
          style: AppTextStyles.small.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _confirmWipe() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Wipe',
      pageBuilder: (context, _, __) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reset Local Database', style: AppTextStyles.h2),
                  const SizedBox(height: 12),
                  Text(
                    'This will erase all subjects, offline notes, and flashcards. This action cannot be undone.',
                    style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TemariButton(
                          label: 'Cancel',
                          variant: TemariButtonVariant.secondary,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TemariButton(
                          label: 'Delete All',
                          color: AppColors.error,
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final router = GoRouter.of(context);
                            navigator.pop();
                            await ref.read(hiveServiceProvider).wipeLocalData();
                            ref.read(hiveTickProvider.notifier).state++;
                            router.go('/splash');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final settings = ref.watch(settingsControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final email = auth.session?.user.email;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (No AppBar default)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  ScaleOnPress(
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
                  const SizedBox(width: 16),
                  Text(
                    AppStrings.get('settings', lang),
                    style: AppTextStyles.h1.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),

            // Settings list content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Premium Upgrade Banner if not Pro
                  if (!settings.isPro) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.accent, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Temari Pro',
                                style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unlock complete multimodal uploads, dynamic mind mapping, progress dashboard, and infinite learning limits.',
                            style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                          ),
                          const SizedBox(height: 18),
                          TemariButton(
                            label: 'Upgrade for \$2.99',
                            onPressed: () => ProPaywallSheet.show(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    // Pro Active Status card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.success, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Temari Pro Active Lifetime',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Account Profile Info
                  _SectionHeader(title: AppStrings.get('account', lang)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.person_outline_rounded, color: AppColors.inkMid),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settings.displayName ?? 'Temari Student',
                                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email ?? 'Local Offline Mode',
                                    style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (auth.anonymous) ...[
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.get('create_account_sync', lang),
                            style: AppTextStyles.small.copyWith(color: AppColors.inkMid),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TemariButton(
                          label: AppStrings.get('sign_out', lang),
                          variant: TemariButtonVariant.secondary,
                          onPressed: () async {
                            final router = GoRouter.of(context);
                            await ref.read(authControllerProvider).signOut();
                            router.go('/auth');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Study Preferences
                  _SectionHeader(title: AppStrings.get('study_preferences', lang)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // Language change trigger card
                        _SettingsActionRow(
                          title: 'App Language',
                          value: lang == 'am' ? 'አማርኛ' : (lang == 'om' ? 'Afaan Oromo' : 'English'),
                          onTap: () {
                            context.push('/language');
                          },
                        ),
                        const _Divider(),
                        _SettingsSwitchRow(
                          title: AppStrings.get('daily_reminder', lang),
                          value: settings.dailyReminder,
                          onChanged: (v) => settings.setDailyReminder(v),
                        ),
                        const _Divider(),
                        _SettingsSwitchRow(
                          title: AppStrings.get('auto_flashcards', lang),
                          value: settings.autoFlashcards,
                          onChanged: (v) => settings.setAutoFlashcards(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Data Management
                  _SectionHeader(title: AppStrings.get('data', lang)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _SettingsActionRow(
                          title: AppStrings.get('export_data', lang),
                          value: 'Export JSON',
                          onTap: () {
                            final json = ref.read(hiveServiceProvider).exportAllJson();
                            _copyBackup(json);
                          },
                        ),
                        const _Divider(),
                        _SettingsActionRow(
                          title: AppStrings.get('delete_local', lang),
                          value: 'Clear',
                          color: AppColors.error,
                          onTap: _confirmWipe,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, color: AppColors.ink),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.accent.withOpacity(0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.color,
  });

  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, color: color ?? AppColors.ink),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.small.copyWith(color: color ?? AppColors.inkLight, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color ?? AppColors.inkLight),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
