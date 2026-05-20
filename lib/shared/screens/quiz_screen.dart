import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/bootstrap_providers.dart';
import '../../core/providers/core_providers.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../shared/widgets/scale_on_press.dart';
import '../../shared/widgets/temari_button.dart';
import '../utils/device_save_helper.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({
    super.key,
    required this.subjectId,
    this.noteId,
  });

  final String subjectId;
  final String? noteId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _questions = [];
  final Map<int, int> _selectedAnswers = {}; // questionIndex -> selectedOptionIndex
  bool _showResults = false;
  String _subjectName = 'Quiz';
  String _combinedContent = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContentAndGenerate());
  }

  void _loadContentAndGenerate() async {
    final hive = ref.read(hiveServiceProvider);
    final subject = hive.getSubject(widget.subjectId);
    if (subject != null) {
      setState(() {
        _subjectName = subject.name;
      });
    }

    if (widget.noteId != null) {
      final note = hive.getNote(widget.noteId!);
      if (note != null) {
        _combinedContent = note.aiExplanation ?? note.content;
      }
    } else {
      final notes = hive.notesForSubject(widget.subjectId);
      _combinedContent = notes
          .map((n) => '${n.title}\n${n.aiExplanation ?? n.content}')
          .join('\n\n');
    }

    if (_combinedContent.trim().isEmpty) {
      return;
    }

    _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _isLoading = true;
      _showResults = false;
      _selectedAnswers.clear();
      _questions.clear();
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);
      
      final quizData = await gemini.generateQuiz(
        content: _combinedContent,
        language: lang,
      );

      setState(() {
        _questions = quizData;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate quiz: $e. Check your internet connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveQuizToDevice() {
    if (_questions.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('=== Temari Quiz: $_subjectName ===');
    buffer.writeln('Date: ${DateTime.now().toLocal()}\n');

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      buffer.writeln('Q${i + 1}: ${q['question']}');
      final options = q['options'] as List;
      for (int o = 0; o < options.length; o++) {
        buffer.writeln('  [ ] ${options[o]}');
      }
      final correctIdx = q['correctIndex'] as int;
      buffer.writeln('Correct Answer: ${options[correctIdx]}\n');
    }

    DeviceSaveHelper.saveTextFile(
      context: context,
      fileName: 'temari_quiz_${DateTime.now().millisecondsSinceEpoch}.txt',
      textContent: buffer.toString(),
    );
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i]['correctIndex']) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: ScaleOnPress(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink, size: 18),
        ),
        title: Text(
          'Quiz: $_subjectName',
          style: AppTextStyles.h2.copyWith(fontSize: 16),
        ),
        actions: [
          if (_questions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_alt_rounded, color: AppColors.accent),
              tooltip: 'Save Quiz to Device',
              onPressed: _saveQuizToDevice,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text('Generating quiz questions using AI...', style: TextStyle(color: AppColors.inkLight)),
                ],
              ),
            )
          : _questions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.quiz_outlined, size: 48, color: AppColors.inkLight),
                        const SizedBox(height: 16),
                        const Text(
                          'No study materials found to generate a quiz.',
                          style: TextStyle(color: AppColors.inkLight),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TemariButton(
                          label: 'Try Again',
                          onPressed: _generateQuiz,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    ...List.generate(_questions.length, (qIdx) {
                      final q = _questions[qIdx];
                      final options = q['options'] as List;
                      final correctIndex = q['correctIndex'] as int;
                      final userSelection = _selectedAnswers[qIdx];

                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${qIdx + 1} of ${_questions.length}',
                                style: AppTextStyles.label.copyWith(color: AppColors.accent),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                q['question'] ?? '',
                                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ...List.generate(options.length, (oIdx) {
                                final optionText = options[oIdx];
                                final isSelected = userSelection == oIdx;
                                final isCorrect = correctIndex == oIdx;

                                Color tileColor = Colors.transparent;
                                Color borderColor = AppColors.border;
                                Widget? feedbackIcon;

                                if (_showResults) {
                                  if (isCorrect) {
                                    tileColor = Colors.green.withValues(alpha: 0.1);
                                    borderColor = Colors.green;
                                    feedbackIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18);
                                  } else if (isSelected) {
                                    tileColor = Colors.red.withValues(alpha: 0.1);
                                    borderColor = Colors.red;
                                    feedbackIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 18);
                                  }
                                } else if (isSelected) {
                                  tileColor = AppColors.accentSoft;
                                  borderColor = AppColors.accent;
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: _showResults
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedAnswers[qIdx] = oIdx;
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: tileColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor, width: isSelected || (_showResults && isCorrect) ? 2 : 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              optionText,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: isSelected && !_showResults ? AppColors.accent : AppColors.ink,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (feedbackIcon != null) ...[
                                            const SizedBox(width: 8),
                                            feedbackIcon,
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    if (!_showResults)
                      TemariButton(
                        label: 'Submit Answers',
                        onPressed: _selectedAnswers.length < _questions.length
                            ? null
                            : () {
                                setState(() {
                                  _showResults = true;
                                });
                                HapticFeedback.mediumImpact();
                              },
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Quiz Completed! 🎉',
                              style: AppTextStyles.h2.copyWith(color: AppColors.accent),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your Score: ${_calculateScore()} / ${_questions.length}',
                              style: AppTextStyles.h1.copyWith(fontSize: 24, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TemariButton(
                              label: 'Export Result 💾',
                              variant: TemariButtonVariant.secondary,
                              onPressed: _saveQuizToDevice,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TemariButton(
                              label: 'Retake Quiz ✦',
                              onPressed: _generateQuiz,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
    );
  }
}
