import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/subjects_provider.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final allSubjects = ref.watch(subjectsProvider);
    final hive = ref.watch(hiveServiceProvider);
    final displayName = ref.watch(settingsControllerProvider).displayName ?? 'Wada';

    final filteredSubjects = allSubjects.where((s) {
      final name = s.name.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      floatingActionButton: ScaleOnPress(
        onTap: () => context.push('/subjects/new'),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGlow.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header with dynamic counts matching HomeScreen
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text(
                    AppStrings.get('your_subjects', lang),
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
                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'T',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(
                '${allSubjects.length} academic study hubs active',
                style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
              ),
            ),

            // Sleek Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.inkLight, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: AppTextStyles.body.copyWith(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search study hubs...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Icon(Icons.clear_rounded, color: AppColors.inkLight, size: 18),
                      ),
                  ],
                ),
              ),
            ),

            // Staggered premium subjects grid
            Expanded(
              child: filteredSubjects.isEmpty
                  ? Center(
                      child: EmptyState(
                        title: _searchQuery.isEmpty
                            ? AppStrings.get('empty_subjects', lang)
                            : 'No matching subjects found.',
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredSubjects.length,
                      itemBuilder: (ctx, idx) {
                        final s = filteredSubjects[idx];
                        final color = _parseColor(s.colorHex);
                        final notesCount = hive.notesForSubject(s.id).length;
                        final cardsCount = hive.flashcardsForSubject(s.id).length;

                        return ScaleOnPress(
                          onTap: () => context.push('/subject/${s.id}'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border, width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Matching colored corner tag
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Colored hub circle
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.import_contacts_rounded,
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Title
                                      Text(
                                        s.name,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.ink,
                                          fontSize: 15,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      // Information badges
                                      Row(
                                        children: [
                                          Icon(Icons.description_outlined, color: AppColors.inkLight, size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '$notesCount',
                                              style: AppTextStyles.label.copyWith(color: AppColors.inkMid),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(Icons.style_outlined, color: AppColors.inkLight, size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '$cardsCount',
                                              style: AppTextStyles.label.copyWith(color: AppColors.inkMid),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
