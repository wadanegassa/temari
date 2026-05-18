import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/flashcard.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../settings/providers/settings_provider.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late final TextEditingController _title = TextEditingController();
  String _displayLang = 'en';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _regenerate(String lang) async {
    final hive = ref.read(hiveServiceProvider);
    final n = hive.getNote(widget.noteId);
    if (n == null) return;
    n.aiExplanationByLang ??= {};
    if (n.aiExplanationByLang!.containsKey(lang)) {
      setState(() {
        _displayLang = lang;
        _title.text = n.title;
      });
      return;
    }
    final gemini = ref.read(geminiServiceProvider);
    final buffer = StringBuffer();
    final stream = gemini.explainText(
      content: n.content,
      language: lang,
    );
    await for (final c in stream) {
      buffer.write(c);
    }
    n.aiExplanationByLang![lang] = buffer.toString();
    n.aiExplanation = buffer.toString();
    n.language = lang;
    await hive.upsertNote(n);
    await ref.read(supabaseServiceProvider).pushUpsertNote(n);
    setState(() => _displayLang = lang);
    ref.read(hiveTickProvider.notifier).state++;
  }

  Future<void> _predict() async {
    final lang = ref.read(languageProvider);
    final n = ref.read(hiveServiceProvider).getNote(widget.noteId);
    if (n == null) return;
    final gemini = ref.read(geminiServiceProvider);
    final qs = await gemini.predictExamQuestions(
      content: n.aiExplanation ?? n.content,
      language: lang,
    );
    n.predictedQuestions = qs;
    await ref.read(hiveServiceProvider).upsertNote(n);
    setState(() {});
  }

  Future<void> _flashcards() async {
    final n = ref.read(hiveServiceProvider).getNote(widget.noteId);
    if (n == null) return;
    final lang = ref.read(languageProvider);
    final gemini = ref.read(geminiServiceProvider);
    final cards = await gemini.generateFlashcards(
      content: n.aiExplanation ?? n.content,
      language: lang,
      count: 10,
    );
    final hive = ref.read(hiveServiceProvider);
    for (final c in cards) {
      final f = Flashcard.create(
        userId: n.userId,
        noteId: n.id,
        subjectId: n.subjectId,
        question: c['question']!,
        answer: c['answer']!,
      );
      await hive.upsertFlashcard(f);
      await ref.read(supabaseServiceProvider).pushUpsertFlashcard(f);
    }
    ref.read(hiveTickProvider.notifier).state++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
    final n = ref.watch(hiveServiceProvider).getNote(widget.noteId);
    if (n == null) {
      return const Scaffold(body: Center(child: Text('Not found')));
    }
    if (_title.text.isEmpty) {
      _title.text = n.title;
      _displayLang = n.language;
    }
    final explanation = n.aiExplanationByLang?[_displayLang] ??
        n.aiExplanation ??
        '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(AppStrings.get('note_title', lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            style: AppTextStyles.h2,
            decoration: const InputDecoration(border: InputBorder.none),
            onSubmitted: (v) async {
              n.title = v;
              await ref.read(hiveServiceProvider).upsertNote(n);
            },
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('EN'),
                selected: _displayLang == 'en',
                onSelected: (_) => _regenerate('en'),
              ),
              FilterChip(
                label: const Text('AM'),
                selected: _displayLang == 'am',
                onSelected: (_) => _regenerate('am'),
              ),
              FilterChip(
                label: const Text('OM'),
                selected: _displayLang == 'om',
                onSelected: (_) => _regenerate('om'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(AppStrings.get('original_content', lang), style: AppTextStyles.label),
          Text(n.content, style: AppTextStyles.body),
          const SizedBox(height: 24),
          Text(AppStrings.get('ai_explanation', lang), style: AppTextStyles.label),
          Text(explanation, style: AppTextStyles.body),
          TextButton(
            onPressed: () => _regenerate(lang),
            child: Text(AppStrings.get('regenerate', lang)),
          ),
          TemariButton(
            label: AppStrings.get('generate_flashcards', lang),
            onPressed: _flashcards,
          ),
          const SizedBox(height: 24),
          Text(AppStrings.get('predicted_exam', lang), style: AppTextStyles.label),
          if (n.predictedQuestions != null)
            ...n.predictedQuestions!.map((q) => Text('• $q', style: AppTextStyles.body)),
          TextButton(onPressed: _predict, child: const Text('Load predictions')),
        ],
      ),
    );
  }
}
