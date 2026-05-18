import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';
import '../widgets/recent_note_tile.dart';
import '../widgets/study_streak_banner.dart';
import '../widgets/subject_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting(String lang) {
    final h = DateTime.now().hour;
    if (h < 12) return AppStrings.get('home_greeting', lang);
    if (h < 17) return AppStrings.get('home_greeting_afternoon', lang);
    return AppStrings.get('home_greeting_evening', lang);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
    final subjects = ref.watch(subjectsProvider);
    final notes = ref.watch(hiveServiceProvider).notes;
    final name = ref.watch(settingsControllerProvider).displayName ?? 'Wada';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Text(
                      AppStrings.get('app_name', lang),
                      style: AppTextStyles.h3.copyWith(letterSpacing: -0.2),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      color: AppColors.textPrimary,
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting(lang)}, $name 👋',
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 12),
                    const StudyStreakBanner(),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.get('quick_add_voice', lang),
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 76,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _Quick(
                            icon: Icons.mic_none_rounded,
                            bg: const Color(0xFFE8F0FF),
                            label: AppStrings.get('quick_add_voice', lang),
                            onTap: () => context.push('/note/voice'),
                          ),
                          _Quick(
                            icon: Icons.photo_camera_outlined,
                            bg: const Color(0xFFF3E8FF),
                            label: AppStrings.get('quick_add_photo', lang),
                            onTap: () => context.push('/note/photo'),
                          ),
                          _Quick(
                            icon: Icons.picture_as_pdf_outlined,
                            bg: const Color(0xFFE7F8EF),
                            label: AppStrings.get('quick_add_file', lang),
                            onTap: () => context.push('/note/pdf'),
                          ),
                          _Quick(
                            icon: Icons.edit_outlined,
                            bg: const Color(0xFFFFF4E5),
                            label: AppStrings.get('quick_add_text', lang),
                            onTap: () => context.push('/note/text'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          AppStrings.get('your_subjects', lang),
                          style: AppTextStyles.h3,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/subjects/new'),
                          child: Text(AppStrings.get('add_subject', lang)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (subjects.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppStrings.get('empty_subjects', lang),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      final count =
                          notes.where((n) => n.subjectId == s.id).length;
                      return SubjectCard(
                        subject: s,
                        noteCount: count,
                        onTap: () => context.push('/subject/${s.id}'),
                      );
                    },
                    childCount: subjects.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                child: Text(
                  AppStrings.get('recent_notes', lang),
                  style: AppTextStyles.h3,
                ),
              ),
            ),
            if (notes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    AppStrings.get('empty_notes', lang),
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final n = notes[i];
                    final sub =
                        subjects.firstWhereOrNull((s) => s.id == n.subjectId);
                    final subName = sub?.name ?? '';
                    return RecentNoteTile(
                      note: n,
                      subjectName: subName,
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

class _Quick extends StatefulWidget {
  const _Quick({
    required this.icon,
    required this.bg,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Quick> createState() => _QuickState();
}

class _QuickState extends State<_Quick> {
  double _s = 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _s = 0.97),
            onTapCancel: () => setState(() => _s = 1),
            onTapUp: (_) => setState(() => _s = 1),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _s,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(widget.icon, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              widget.label,
              style: AppTextStyles.label.copyWith(fontSize: 11),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
