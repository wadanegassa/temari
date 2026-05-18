import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../shared/widgets/language_selector.dart';
import '../../../shared/widgets/temari_button.dart';
import '../providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final settings = ref.watch(settingsControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final email = auth.session?.user.email;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(AppStrings.get('settings', lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(AppStrings.get('account', lang), style: AppTextStyles.label),
          ListTile(
            title: Text(settings.displayName ?? '—', style: AppTextStyles.body),
            subtitle: Text(email ?? AppStrings.get('continue_without', lang)),
          ),
          if (auth.anonymous)
            Text(
              AppStrings.get('create_account_sync', lang),
              style: AppTextStyles.bodySmall,
            ),
          TemariButton(
            label: AppStrings.get('sign_out', lang),
            onPressed: () async {
              await ref.read(authControllerProvider).signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
          const Divider(height: 40),
          Text(AppStrings.get('study_preferences', lang), style: AppTextStyles.label),
          const SizedBox(height: 8),
          const LanguageSelector(),
          SwitchListTile(
            title: Text(AppStrings.get('daily_reminder', lang)),
            value: settings.dailyReminder,
            onChanged: (v) => ref.read(settingsControllerProvider).setDailyReminder(v),
          ),
          SwitchListTile(
            title: Text(AppStrings.get('auto_flashcards', lang)),
            value: settings.autoFlashcards,
            onChanged: (v) => ref.read(settingsControllerProvider).setAutoFlashcards(v),
          ),
          const Divider(height: 40),
          Text(AppStrings.get('data', lang), style: AppTextStyles.label),
          ListTile(
            title: Text(AppStrings.get('export_data', lang)),
            onTap: () {
              final json = ref.read(hiveServiceProvider).exportAllJson();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${json.length} chars (copy in future)')),
              );
            },
          ),
          ListTile(
            title: Text(AppStrings.get('delete_local', lang)),
            onTap: () async {
              await ref.read(hiveServiceProvider).wipeLocalData();
              ref.read(hiveTickProvider.notifier).state++;
            },
          ),
          const Divider(height: 40),
          Text(AppStrings.get('about', lang), style: AppTextStyles.label),
          Text(AppStrings.get('built_for', lang), style: AppTextStyles.body),
          Text('v1.0.0', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
