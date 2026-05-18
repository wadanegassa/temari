import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../settings/providers/settings_provider.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
    final subject = ref.watch(hiveServiceProvider).getSubject(widget.subjectId);
    final notes = ref
        .watch(hiveServiceProvider)
        .notesForSubject(widget.subjectId);
    final cards =
        ref.watch(hiveServiceProvider).flashcardsForSubject(widget.subjectId);
    if (subject == null) {
      return const Scaffold(body: Center(child: Text('Missing subject')));
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(subject.name, style: AppTextStyles.h3),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: AppStrings.get('notes_tab', lang)),
            Tab(text: AppStrings.get('flashcards_tab', lang)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    return ListTile(
                      title: Text(n.title.isEmpty ? 'Note' : n.title),
                      subtitle: Text(
                        n.aiSummary ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.push('/note/${n.id}'),
                      onLongPress: () async {
                        await ref.read(hiveServiceProvider).deleteNote(n.id);
                        ref.read(hiveTickProvider.notifier).state++;
                      },
                    );
                  },
                ),
                ListView.builder(
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
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.push('/exam/${widget.subjectId}'),
                  child: Text(AppStrings.get('exam_mode', lang)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
