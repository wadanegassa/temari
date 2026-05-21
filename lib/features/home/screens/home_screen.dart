import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';
import '../widgets/recent_note_tile.dart';
import '../widgets/study_streak_banner.dart';
import '../widgets/subject_card.dart';
import '../../../shared/widgets/scale_on_press.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(String lang) {
    final h = DateTime.now().hour;
    if (h < 12) return AppStrings.get('home_greeting', lang);
    if (h < 17) return AppStrings.get('home_greeting_afternoon', lang);
    return AppStrings.get('home_greeting_evening', lang);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  void _selectSubjectAndNavigate(BuildContext context, WidgetRef ref, String title, Function(String subjectId) onSelected) {
    final subjects = ref.read(subjectsProvider);
    if (subjects.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Subjects Found'),
          content: const Text('Create a subject first to keep your notes and materials organized.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/subjects/new');
              },
              child: const Text('Create Subject'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final s = subjects[index];
                      final color = _parseColor(s.colorHex);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(Icons.book, color: color),
                        ),
                        title: Text(s.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(s.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
    final subjects = ref.watch(subjectsProvider);
    final notes = ref.watch(hiveServiceProvider).notes;
    final name = ref.watch(settingsControllerProvider).displayName ?? 'Wada';

    // Mock active study timer check (we'll implement the actual Pomodoro notifier shortly)
    final timerSessionBox = ref.watch(hiveServiceProvider).timerSessions;
    final isTimerActive = timerSessionBox.isNotEmpty && 
        DateTime.now().difference(timerSessionBox.first.createdAt).inMinutes < timerSessionBox.first.durationMinutes;
    
    final formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    // Calculate due cards summary across subjects
    final flashcards = ref.watch(hiveServiceProvider).flashcards;
    final dueCards = flashcards.where((c) => c.nextReview.isBefore(DateTime.now())).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Nav Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Temari',
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    ScaleOnPress(
                      onTap: () => context.push('/settings'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Greeting Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting(lang)}, $name',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.inkLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Streak Banner (🔥)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: StudyStreakBanner(),
              ),
            ),

            // Study Timer Pill-Card (Visible if a Pomodoro focus state is running)
            if (isTimerActive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: ScaleOnPress(
                    onTap: () => context.push('/timer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(100),
                        border: const Border(
                          left: BorderSide(color: AppColors.accent, width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Focus Round is active · Learning',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'View →',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.accentGlow,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Quick Actions "QUICK ADD"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK ADD',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.inkLight,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _QuickActionTile(
                          icon: Icons.edit_note_outlined,
                          label: AppStrings.get('quick_add_unified', lang),
                          onTap: () => _selectSubjectAndNavigate(
                            context,
                            ref,
                            AppStrings.get('quick_add_unified', lang),
                            (sid) => context.push('/note/voice?subjectId=$sid'),
                          ),
                        ),
                        _QuickActionTile(
                          icon: Icons.photo_camera_outlined,
                          label: AppStrings.get('quick_add_photo', lang),
                          onTap: () => _selectSubjectAndNavigate(
                            context,
                            ref,
                            AppStrings.get('quick_add_photo', lang),
                            (sid) => context.push('/note/photo?subjectId=$sid&immediate=true'),
                          ),
                        ),
                        _QuickActionTile(
                          icon: Icons.upload_file_outlined,
                          label: AppStrings.get('quick_add_file', lang),
                          onTap: () => _selectSubjectAndNavigate(
                            context,
                            ref,
                            AppStrings.get('quick_add_file', lang),
                            (sid) => context.push('/note/pdf?subjectId=$sid'),
                          ),
                        ),
                        _QuickActionTile(
                          icon: Icons.quiz_outlined,
                          label: AppStrings.get('quick_add_quizzes', lang),
                          onTap: () => _selectSubjectAndNavigate(
                            context,
                            ref,
                            AppStrings.get('quick_add_quizzes', lang),
                            (sid) => context.push('/quiz-session?subjectId=$sid'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Due for Review horizontal pill (if flashcards are pending review)
            if (dueCards.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: ScaleOnPress(
                    onTap: () {
                      final randomDue = dueCards.first;
                      context.push('/exam/${randomDue.subjectId}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.warning, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.style_outlined, color: AppColors.warning, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${dueCards.length} flashcards due for review today',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.warning, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Subjects Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    Text(
                      AppStrings.get('your_subjects', lang),
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    ScaleOnPress(
                      onTap: () => context.push('/subjects'),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          'See all →',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (subjects.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppStrings.get('empty_subjects', lang),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMid,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final s = subjects[i];
                      final count = notes.where((n) => n.subjectId == s.id).length;
                      return SubjectCard(
                        subject: s,
                        noteCount: count,
                        onTap: () => context.push('/subject/${s.id}'),
                      );
                    },
                    childCount: subjects.length > 4 ? 4 : subjects.length,
                  ),
                ),
              ),

            // Recently Added Notes Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  lang == 'am'
                      ? 'የቅርብ ጊዜ ማስታወሻዎች'
                      : (lang == 'om' ? 'Yaadannoo dhiyoo' : 'Recently Added'),
                  style: AppTextStyles.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),

            if (notes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppStrings.get('empty_notes', lang),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMid,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final n = notes[i];
                    final sub = subjects.firstWhereOrNull((s) => s.id == n.subjectId);
                    final subName = sub?.name ?? '';
                    Color? subColor;
                    if (sub != null) {
                      try {
                        subColor = Color(int.parse('FF${sub.colorHex.replaceAll('#', '')}', radix: 16));
                      } catch (_) {}
                    }
                    return RecentNoteTile(
                      note: n,
                      subjectName: subName,
                      subjectColor: subColor,
                      onTap: () => context.push('/note/${n.id}'),
                    );
                  },
                  childCount: notes.length > 5 ? 5 : notes.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleOnPress(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                )
              ],
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.inkMid,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
