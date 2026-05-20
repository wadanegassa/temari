import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/voice_service.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/pro_paywall_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';

class VoiceNoteScreen extends HookConsumerWidget {
  const VoiceNoteScreen({super.key, this.subjectId});

  final String? subjectId;

  String _subject(WidgetRef ref) {
    final subs = ref.read(subjectsProvider);
    if (subjectId != null) return subjectId!;
    return subs.isNotEmpty ? subs.first.id : '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isRecording = useState(false);
    final titleController = useTextEditingController();
    final bodyController = useTextEditingController();
    
    // Listen to changes in the editors to update state
    useValueListenable(titleController);
    useValueListenable(bodyController);
    
    final explanation = useState('');
    final explaining = useState(false);
    
    final voice = ref.read(voiceServiceProvider);
    
    // Wave animation controller
    final waveAnimController = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    );

    useEffect(() {
      voice.init();
      return null;
    }, []);

    useEffect(() {
      if (isRecording.value) {
        waveAnimController.repeat();
      } else {
        waveAnimController.stop();
      }
      return null;
    }, [isRecording.value]);

    Future<void> toggleRecording() async {
      final settings = ref.read(settingsControllerProvider);
      final hive = ref.read(hiveServiceProvider);
      
      // Limit Check: Max 5 multimodal notes for free users
      final multiNotes = hive.notes.where((n) => n.type == 'voice' || n.type == 'photo' || n.type == 'file');
      if (!settings.isPro && multiNotes.length >= 5) {
        ProPaywallSheet.show(context);
        return;
      }

      if (isRecording.value) {
        await voice.stop();
        isRecording.value = false;
        HapticFeedback.heavyImpact();
      } else {
        final initialText = bodyController.text;
        await voice.startListening((t) {
          // Append transcribed text cleanly at the end
          bodyController.text = initialText.isEmpty ? t : '$initialText\n$t';
          bodyController.selection = TextSelection.fromPosition(
            TextPosition(offset: bodyController.text.length),
          );
        });
        isRecording.value = true;
        HapticFeedback.mediumImpact();
      }
    }

    Future<void> explain() async {
      if (bodyController.text.isEmpty) return;

      explaining.value = true;
      explanation.value = '';
      
      try {
        final gemini = ref.read(geminiServiceProvider);
        final sid = _subject(ref);
        final subject = ref.read(hiveServiceProvider).getSubject(sid);
        final subjectName = subject?.name;

        final stream = gemini.explainText(
          content: bodyController.text,
          language: lang,
          subjectName: subjectName,
        );
        await for (final chunk in stream) {
          explanation.value += chunk;
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI explanation requires an internet connection.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        explaining.value = false;
      }
    }

    Future<void> saveNote() async {
      final sid = _subject(ref);
      if (sid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or create a subject first.')),
        );
        return;
      }

      final title = titleController.text.trim();
      final body = bodyController.text.trim();

      if (body.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note content cannot be empty.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final uid = ref.read(authControllerProvider).effectiveUserId;
      final finalTitle = title.isEmpty ? '${body.split(' ').take(5).join(' ')}...' : title;

      final n = Note.create(
        userId: uid,
        subjectId: sid,
        type: noteTypeText, // Combined is saved as standard text note
        title: finalTitle,
        content: body,
        language: lang,
      );
      n.aiExplanation = explanation.value;
      n.aiSummary = explanation.value.length > 120
          ? '${explanation.value.substring(0, 120)}…'
          : explanation.value;

      await ref.read(hiveServiceProvider).upsertNote(n);
      await ref.read(supabaseServiceProvider).pushUpsertNote(n);

      ref.read(hiveTickProvider.notifier).state++;
      HapticFeedback.heavyImpact();
      
      if (context.mounted) {
        context.pop();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header
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
                    'Unified Study Note 📝',
                    style: AppTextStyles.h1.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Type your academic notes below, record active lectures, or mix both! Temari synthesizes and explains everything instantly.',
                    style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                  ),
                  const SizedBox(height: 24),

                  // Binder Card for Title and Description
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.02),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Editor
                        TextField(
                          controller: titleController,
                          style: AppTextStyles.h2.copyWith(fontSize: 18, color: AppColors.ink, fontWeight: FontWeight.w900),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Note Title (e.g. Chemical Bonds)...',
                            hintStyle: TextStyle(color: AppColors.inkLight),
                            isDense: true,
                          ),
                        ),
                        const Divider(color: AppColors.border, height: 20, thickness: 1),
                        // Body Editor
                        TextField(
                          controller: bodyController,
                          maxLines: 10,
                          minLines: 6,
                          style: AppTextStyles.body.copyWith(color: AppColors.ink, height: 1.55, fontSize: 14.5),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Type your study notes here or start dictating below...',
                            hintStyle: TextStyle(color: AppColors.inkLight),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Audio Visualizer waveform (shown while recording)
                  if (isRecording.value) ...[
                    AnimatedBuilder(
                      animation: waveAnimController,
                      builder: (context, _) {
                        return SizedBox(
                          height: 70,
                          child: CustomPaint(
                            size: const Size(double.infinity, 70),
                            painter: WaveformPainter(
                              active: isRecording.value,
                              animationValue: waveAnimController.value,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Dictation Control Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRecording.value ? AppColors.error.withValues(alpha: 0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRecording.value ? AppColors.error.withValues(alpha: 0.2) : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        ScaleOnPress(
                          onTap: toggleRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isRecording.value ? AppColors.error : AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isRecording.value ? AppColors.error : AppColors.accent)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Icon(
                              isRecording.value ? Icons.stop_rounded : Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRecording.value ? 'RECORDING LECTURE...' : 'VOICE DICTATION',
                                style: AppTextStyles.label.copyWith(
                                  color: isRecording.value ? AppColors.error : AppColors.inkMid,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRecording.value
                                    ? 'Speaking... Temari is capturing text live.'
                                    : 'Tap the microphone to speak your notes.',
                                style: AppTextStyles.small.copyWith(
                                  color: isRecording.value ? AppColors.error : AppColors.inkLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions row
                  if (bodyController.text.isNotEmpty && explanation.value.isEmpty) ...[
                    TemariButton(
                      label: explaining.value ? 'Generating AI Explanations...' : AppStrings.get('explain_ai', lang),
                      onPressed: explaining.value ? null : explain,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (explaining.value) ...[
                    const LoadingShimmer(),
                    const SizedBox(height: 24),
                  ],

                  // AI Explanation details
                  if (explanation.value.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'AI TUTOR INSIGHTS',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.successSoft.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.2), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        explanation.value,
                        style: AppTextStyles.body.copyWith(color: AppColors.inkMid, height: 1.55, fontSize: 14.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Standard save button
                  if (bodyController.text.isNotEmpty) ...[
                    TemariButton(
                      label: AppStrings.get('save', lang),
                      onPressed: saveNote,
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({required this.active, required this.animationValue});

  final bool active;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paintFore = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: active
            ? [AppColors.error, AppColors.accentGlow]
            : [AppColors.accent, AppColors.accentSoft],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final paintBack = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: active
            ? [AppColors.error.withValues(alpha: 0.15), AppColors.accentGlow.withValues(alpha: 0.05)]
            : [AppColors.accent.withValues(alpha: 0.15), AppColors.accentSoft.withValues(alpha: 0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    const barsCount = 32;
    final widthFactor = size.width / barsCount;

    for (var i = 0; i < barsCount; i++) {
      final x = widthFactor * i + (widthFactor / 2);
      double height;

      if (active) {
        final angle = (animationValue * 2 * math.pi) + (i * 0.3);
        height = 16 + 48 * (0.5 + 0.5 * math.sin(angle));
      } else {
        height = 8.0 + 6.0 * math.sin(i * 0.25);
      }

      // Draw background wave
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: 6.0,
            height: height + 6.0,
          ),
          const Radius.circular(3),
        ),
        paintBack,
      );

      // Draw foreground wave
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: 3.5,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paintFore,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.animationValue != animationValue;
  }
}
