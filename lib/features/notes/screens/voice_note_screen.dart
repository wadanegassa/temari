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
    final transcription = useState('');
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
        transcription.value = '';
        await voice.startListening((t) {
          transcription.value = t;
        });
        isRecording.value = true;
        HapticFeedback.mediumImpact();
      }
    }

    Future<void> explain() async {
      if (transcription.value.isEmpty) return;

      explaining.value = true;
      explanation.value = '';
      
      try {
        final gemini = ref.read(geminiServiceProvider);
        final sid = _subject(ref);
        final subject = ref.read(hiveServiceProvider).getSubject(sid);
        final subjectName = subject?.name;

        final stream = gemini.explainText(
          content: transcription.value,
          language: lang,
          subjectName: subjectName,
        );
        await for (final chunk in stream) {
          explanation.value += chunk;
        }
      } catch (_) {
        // recovery
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

      final uid = ref.read(authControllerProvider).effectiveUserId;
      final title = transcription.value.split(' ').take(5).join(' ');
      final n = Note.create(
        userId: uid,
        subjectId: sid,
        type: noteTypeVoice,
        title: title.isEmpty ? 'Voice Note' : title,
        content: transcription.value,
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
            // Custom Header
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
                    AppStrings.get('quick_add_voice', lang),
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
                  const SizedBox(height: 12),
                  Text(
                    'Record or upload audio lectures. Temari transcribes and explains core concepts instantly.',
                    style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                  ),
                  const SizedBox(height: 32),

                  // Animated audio waveform
                  AnimatedBuilder(
                    animation: waveAnimController,
                    builder: (context, _) {
                      return SizedBox(
                        height: 100,
                        child: CustomPaint(
                          size: const Size(double.infinity, 100),
                          painter: WaveformPainter(
                            active: isRecording.value,
                            animationValue: waveAnimController.value,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Capture Control Button
                  Center(
                    child: ScaleOnPress(
                      onTap: toggleRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: isRecording.value ? AppColors.error : AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: isRecording.value
                              ? [
                                  BoxShadow(
                                    color: AppColors.error.withOpacity(0.35),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.2),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  )
                                ],
                        ),
                        child: Icon(
                          isRecording.value ? Icons.stop_rounded : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Transcription Output
                  if (transcription.value.isNotEmpty) ...[
                    Text(
                      'LIVE TRANSCRIPTION',
                      style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        transcription.value,
                        style: AppTextStyles.body.copyWith(color: AppColors.ink, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    if (explanation.value.isEmpty)
                      TemariButton(
                        label: explaining.value ? 'Generating AI Explanations...' : AppStrings.get('explain_ai', lang),
                        onPressed: explaining.value ? null : explain,
                      ),
                    if (explaining.value) ...[
                      const SizedBox(height: 16),
                      const LoadingShimmer(),
                    ],
                  ],

                  // AI Explanation details
                  if (explanation.value.isNotEmpty) ...[
                    Text(
                      'AI SUMMARY',
                      style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        explanation.value,
                        style: AppTextStyles.small.copyWith(color: AppColors.inkMid, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 32),
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
    final paint = Paint()
      ..color = active ? AppColors.error.withOpacity(0.4) : AppColors.accent.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    const barsCount = 28;
    final widthFactor = size.width / barsCount;

    for (var i = 0; i < barsCount; i++) {
      final x = widthFactor * i + (widthFactor / 2);
      double height;

      if (active) {
        // Animate sin waves based on periodic time and index offsets
        final angle = (animationValue * 2 * math.pi) + (i * 0.4);
        height = 14 + 36 * (0.5 + 0.5 * math.sin(angle));
      } else {
        height = 6.0 + 4.0 * math.sin(i * 0.2);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: 3.5,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.active != active || oldDelegate.animationValue != animationValue;
  }
}
