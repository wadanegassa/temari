import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../shared/models/exam_session.dart';
import '../../../shared/models/flashcard.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../widgets/flashcard_widget.dart';

class ExamModeScreen extends ConsumerStatefulWidget {
  const ExamModeScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<ExamModeScreen> createState() => _ExamModeScreenState();
}

class _ExamModeScreenState extends ConsumerState<ExamModeScreen> {
  List<Flashcard> _queue = [];
  var _index = 0;
  var _correct = 0;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = ProviderScope.containerOf(context);
      final all =
          c.read(hiveServiceProvider).flashcardsForSubject(widget.subjectId);
      setState(() {
        _queue = List.of(all)..shuffle();
      });
    });
  }

  Future<void> _finish() async {
    final uid = ref.read(authControllerProvider).effectiveUserId;
    final s = ExamSession.create(
      userId: uid,
      subjectId: widget.subjectId,
      totalCards: _queue.length,
      correctCount: _correct,
    );
    await ref.read(hiveServiceProvider).upsertSession(s);
    ref.read(hiveTickProvider.notifier).state++;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    if (!_started) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exam', style: AppTextStyles.h1),
                const SizedBox(height: 12),
                Text('${_queue.length} cards', style: AppTextStyles.body),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _started = true);
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                  },
                  child: Text(AppStrings.get('exam_begin', lang)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_index >= _queue.length) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final pct = _queue.isEmpty ? 0 : (_correct / _queue.length * 100).round();
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$pct%', style: AppTextStyles.h1),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _finish,
                  child: Text(AppStrings.get('exam_done', lang)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = _queue[_index];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('${_index + 1}/${_queue.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            context.pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: FlashcardWidget(
          key: ValueKey(card.id),
          question: card.question,
          answer: card.answer,
          onResult: (r) {
            applyReviewResult(card, r);
            ref.read(hiveServiceProvider).upsertFlashcard(card);
            if (r == 2) _correct++;
            setState(() => _index++);
          },
        ),
      ),
    );
  }
}
