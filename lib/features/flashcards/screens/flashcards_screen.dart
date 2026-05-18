import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../settings/providers/settings_provider.dart';

class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final cards =
        ref.watch(hiveServiceProvider).flashcardsForSubject(subjectId);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppStrings.get('flashcards_tab', lang)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final c = cards[i];
          return ListTile(
            title: Text(c.question, maxLines: 2),
            onTap: () {},
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.push('/exam/$subjectId'),
            child: Text(AppStrings.get('exam_mode', lang)),
          ),
        ),
      ),
    );
  }
}
