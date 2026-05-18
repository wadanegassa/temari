import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/subjects_provider.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final list = ref.watch(subjectsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title:
            Text(AppStrings.get('your_subjects', lang), style: AppTextStyles.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/subjects/new');
            },
          ),
        ],
      ),
      body: list.isEmpty
          ? EmptyState(title: AppStrings.get('empty_subjects', lang))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return ListTile(
                  title: Text(s.name, style: AppTextStyles.body),
                  onTap: () => context.push('/subject/${s.id}'),
                );
              },
            ),
    );
  }
}
