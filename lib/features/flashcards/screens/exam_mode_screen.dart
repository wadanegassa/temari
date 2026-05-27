import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/exam_session.dart';
import '../../../shared/models/flashcard.dart';
import '../../../shared/models/sync_task.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/flashcard_widget.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';

class ExamModeScreen extends ConsumerStatefulWidget {
  const ExamModeScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<ExamModeScreen> createState() => _ExamModeScreenState();
}

class _ExamModeScreenState extends ConsumerState<ExamModeScreen> {
  List<Flashcard> _queue = [];
  final List<Flashcard> _weakCards = [];
  int _index = 0;
  int _correct = 0;
  bool _started = false;
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hive = ref.read(hiveServiceProvider);
      final all = hive.flashcardsForSubject(widget.subjectId);
      final today = DateTime.now();
      
      // Load only cards due for review, or all if none are due
      var due = all.where((c) => c.nextReview.isBefore(today)).toList();
      if (due.isEmpty) {
        due = all;
      }

      setState(() {
        _queue = List.of(due)..shuffle();
      });
    });
  }

  Future<void> _finishSession() async {
    final uid = ref.read(authControllerProvider).effectiveUserId;
    final s = ExamSession.create(
      userId: uid,
      subjectId: widget.subjectId,
      totalCards: _queue.length,
      correctCount: _correct,
    );
    final hive = ref.read(hiveServiceProvider);
    await hive.upsertSession(s);
    await hive.enqueueSyncTask(
      SyncTask.create(
        action: 'upsert',
        entityType: 'exam_session',
        entityId: s.id,
        payload: s.toJson(),
      ),
    );
    unawaited(ref.read(syncServiceProvider).syncAll());
    ref.read(hiveTickProvider.notifier).state++;
    if (mounted) context.pop();
  }

  void _handleReviewResult(int result) {
    if (_index >= _queue.length) return;
    
    final card = _queue[_index];
    applyReviewResult(card, result);
    
    // Save locally & sync
    final hive = ref.read(hiveServiceProvider);
    hive.upsertFlashcard(card);
    hive.enqueueSyncTask(
      SyncTask.create(
        action: 'upsert',
        entityType: 'flashcard',
        entityId: card.id,
        payload: card.toJson(),
      ),
    ).then((_) {
      unawaited(ref.read(syncServiceProvider).syncAll());
    });

    if (result == 2) {
      _correct++;
    } else {
      _weakCards.add(card);
    }

    HapticFeedback.lightImpact();
    setState(() {
      _index++;
      _isCardFlipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subject = ref.watch(hiveServiceProvider).subjects.firstWhere(
          (s) => s.id == widget.subjectId,
          orElse: () => throw Exception('Subject not found'),
        );

    // 1. Ready State
    if (!_started) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      'Exam Mode',
                      style: AppTextStyles.h1.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.style_outlined, color: AppColors.accent, size: 40),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Ready to review ${_queue.length} cards?',
                        style: AppTextStyles.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This session tests cards due in ${subject.name}. Stay focused and answer honestly to let the scheduling engine optimize your intervals.',
                        style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      if (_queue.isEmpty)
                        Text(
                          'No flashcards currently created for this subject.',
                          style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                        )
                      else
                        TemariButton(
                          label: 'Start Review',
                          onPressed: () {
                            setState(() => _started = true);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Visual Results State
    if (_index >= _queue.length) {
      final pct = _queue.isEmpty ? 0.0 : (_correct / _queue.length);
      final pctText = '${(pct * 100).round()}%';
      
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    const SizedBox(height: 24),
                    // Custom circular accuracy ring
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(140, 140),
                              painter: AccuracyPainter(percentage: pct),
                            ),
                            Text(
                              pctText,
                              style: AppTextStyles.h1.copyWith(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Session Completed!',
                      style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You answered $_correct of ${_queue.length} cards correctly in ${subject.name}.',
                      style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Weak Cards section
                    if (_weakCards.isNotEmpty) ...[
                      Text(
                        'CARDS TO FOCUS ON',
                        style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: _weakCards.map((c) {
                            final idx = _weakCards.indexOf(c);
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          c.question,
                                          style: AppTextStyles.small.copyWith(
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (idx < _weakCards.length - 1)
                                  Container(height: 1, color: AppColors.border),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: TemariButton(
                  label: 'Back to Home',
                  onPressed: _finishSession,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Active Card Review
    final card = _queue[_index];
    final progress = _index / _queue.length;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav bar + progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  ScaleOnPress(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Exit Session?'),
                          content: const Text('Are you sure you want to exit your active review? Progress will not be saved.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.pop();
                              },
                              child: const Text('Exit'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Card ${_index + 1} of ${_queue.length}',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Immersive Card Stack
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: FlashcardWidget(
                    key: ValueKey(card.id),
                    question: card.question,
                    answer: card.answer,
                    onFlipped: (flipped) {
                      setState(() {
                        _isCardFlipped = flipped;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Response Action Panel (placed BELOW the card, visible only when flipped)
            AnimatedOpacity(
              opacity: _isCardFlipped ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_isCardFlipped,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RatingButton(
                          label: 'Missed',
                          color: AppColors.error,
                          onTap: () => _handleReviewResult(0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RatingButton(
                          label: 'Almost',
                          color: AppColors.warning,
                          onTap: () => _handleReviewResult(1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RatingButton(
                          label: 'Got it',
                          color: AppColors.success,
                          onTap: () => _handleReviewResult(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AccuracyPainter extends CustomPainter {
  AccuracyPainter({required this.percentage});
  final double percentage;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final paintBg = Paint()
      ..color = AppColors.bgSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    final paintFg = Paint()
      ..color = percentage > 0.7
          ? AppColors.success
          : (percentage > 0.4 ? AppColors.warning : AppColors.error)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // starts at 12 o'clock position
      2 * pi * percentage,
      false,
      paintFg,
    );
  }

  @override
  bool shouldRepaint(covariant AccuracyPainter oldDelegate) =>
      oldDelegate.percentage != percentage;
}
