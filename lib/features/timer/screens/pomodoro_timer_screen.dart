import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';
import '../providers/timer_provider.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';

class PomodoroTimerScreen extends ConsumerWidget {
  const PomodoroTimerScreen({super.key});

  String _formatTime(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);
    final subjects = ref.watch(subjectsProvider);
    final lang = ref.watch(languageProvider);

    final progress = timerState.secondsRemaining / timerState.durationSeconds;
    final activeSubject = subjects.firstWhereOrNull((s) => s.id == timerState.selectedSubjectId);

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
                    lang == 'am' ? 'የጥናት ሰዓት ቆጣሪ' : (lang == 'om' ? 'Qo\'annoo sa\'aatii' : 'Study Timer'),
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

                  // Mode pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ModeChip(
                        label: lang == 'am' ? 'ትኩረት (25)' : 'Focus',
                        isSelected: timerState.mode == PomodoroMode.focus,
                        onTap: () => timerNotifier.selectMode(PomodoroMode.focus),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: lang == 'am' ? 'እረፍት (5)' : 'Break',
                        isSelected: timerState.mode == PomodoroMode.shortBreak,
                        onTap: () => timerNotifier.selectMode(PomodoroMode.shortBreak),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: lang == 'am' ? 'ረጅም እረፍት (15)' : 'Long',
                        isSelected: timerState.mode == PomodoroMode.longBreak,
                        onTap: () => timerNotifier.selectMode(PomodoroMode.longBreak),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Interactive Custom Painter Circle + Countdown Text
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(220, 220),
                            painter: TimerProgressPainter(
                              progress: progress,
                              color: timerState.mode == PomodoroMode.focus ? AppColors.accent : AppColors.success,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatTime(timerState.secondsRemaining),
                                style: AppTextStyles.mono.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timerState.mode == PomodoroMode.focus
                                    ? (lang == 'am' ? 'አተኩር' : 'FOCUSING')
                                    : (lang == 'am' ? 'እረፍት' : 'RESTING'),
                                style: AppTextStyles.label.copyWith(
                                  color: timerState.mode == PomodoroMode.focus ? AppColors.accent : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Completed Rounds indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lang == 'am'
                            ? 'ዛሬ የተጠናቀቁ ዙሮች፡ ${timerState.completedSessionsToday}'
                            : 'Completed rounds today: ${timerState.completedSessionsToday}',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMid, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Select Subject Context
                  Text(
                    'STUDY CONTEXT',
                    style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: timerState.selectedSubjectId,
                        hint: Text(
                          lang == 'am' ? 'ለአጠቃላይ ጥናት' : 'General Study',
                          style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkLight),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              lang == 'am' ? 'አጠቃላይ ጥናት' : 'General Study',
                              style: AppTextStyles.body,
                            ),
                          ),
                          ...subjects.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse('FF${s.colorHex.replaceAll('#', '')}', radix: 16)),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(s.name, style: AppTextStyles.body),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (id) => timerNotifier.setSubject(id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Control actions
                  Row(
                    children: [
                      Expanded(
                        child: TemariButton(
                          label: timerState.isRunning
                              ? (lang == 'am' ? 'አቁም' : 'Pause')
                              : (lang == 'am' ? 'ጀምር' : 'Start Focus'),
                          onPressed: () => timerNotifier.toggleTimer(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ScaleOnPress(
                        onTap: () => timerNotifier.resetTimer(),
                        child: Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderStrong, width: 1.5),
                          ),
                          child: const Icon(Icons.replay_rounded, color: AppColors.inkMid),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: isSelected ? AppColors.accent : AppColors.inkMid,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class TimerProgressPainter extends CustomPainter {
  TimerProgressPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final paintBg = Paint()
      ..color = AppColors.bgSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final paintFg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // 12 o'clock start position
      2 * 3.14159 * progress,
      false,
      paintFg,
    );
  }

  @override
  bool shouldRepaint(covariant TimerProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
