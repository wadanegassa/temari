import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../../../shared/widgets/temari_button.dart';
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

    useEffect(() {
      voice.init();
      return null;
    }, []);

    Future<void> toggle() async {
      if (isRecording.value) {
        await voice.stop();
        isRecording.value = false;
      } else {
        transcription.value = '';
        await voice.startListening((t) => transcription.value = t);
        isRecording.value = true;
      }
    }

    Future<void> explain() async {
      final net = await ref.read(connectivityServiceProvider).isConnected;
      if (!net) {
        explaining.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.get('offline_ai_pending', lang))),
          );
        }
        return;
      }
      explaining.value = true;
      explanation.value = '';
      final gemini = ref.read(geminiServiceProvider);
      if (!gemini.hasKey) {
        explaining.value = false;
        return;
      }
      final stream = gemini.explainText(
        content: transcription.value,
        language: lang,
      );
      await for (final chunk in stream) {
        explanation.value += chunk;
      }
      explaining.value = false;
    }

    Future<void> saveNote() async {
      final sid = _subject(ref);
      if (sid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a subject first')),
        );
        return;
      }
      final uid = ref.read(authControllerProvider).effectiveUserId;
      final n = Note.create(
        userId: uid,
        subjectId: sid,
        type: noteTypeVoice,
        title: transcription.value.split(' ').take(6).join(' '),
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
      if (context.mounted) context.pop();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(AppStrings.get('quick_add_voice', lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _WavePainter(active: isRecording.value),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: isRecording.value
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isRecording.value ? Icons.stop : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(transcription.value, style: AppTextStyles.body),
          const SizedBox(height: 16),
          TemariButton(
            label: AppStrings.get('explain_ai', lang),
            onPressed: explaining.value ? null : explain,
          ),
          if (explaining.value) const LoadingShimmer(),
          if (explanation.value.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(explanation.value, style: AppTextStyles.body),
            const SizedBox(height: 16),
            TemariButton(
              label: AppStrings.get('save', lang),
              onPressed: saveNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent.withValues(alpha: 0.35);
    final t = DateTime.now().millisecondsSinceEpoch / 400;
    for (var i = 0; i < 24; i++) {
      final x = size.width / 24 * i;
      final h = active
          ? (20 + 32 * (0.5 + 0.5 * math.sin(t + i * 0.35))).clamp(8.0, 56.0)
          : 10.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, size.height / 2), width: 4, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.active != active;
}
