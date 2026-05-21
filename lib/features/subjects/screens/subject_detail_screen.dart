import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/flashcard.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/models/subject.dart';
import '../providers/subjects_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../home/widgets/recent_note_tile.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen> {
  int _activeTab = 0; // 0: Notes, 1: Flashcards
  bool _isGenerating = false;
  String? _genStatus;

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return AppColors.accent;
  }

  static const List<String> _subjectEditHexes = [
    '#5D4037', // Brown
    '#2E6B9E', // Ocean blue
    '#3A7D5C', // Forest green
    '#7B4EA0', // Plum
    '#B5860D', // Golden
    '#2E7D8C', // Teal
    '#C0392B', // Red
  ];

  void _showEditSubjectDialog(BuildContext context, Subject subject) {
    final nameController = TextEditingController(text: subject.name);
    String selectedHex = subject.colorHex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                    'Edit Subject Details',
                    style: AppTextStyles.h2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Subject Name',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkLight),
                      filled: true,
                      fillColor: AppColors.bgSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Subject Theme Color',
                    style: AppTextStyles.label.copyWith(color: AppColors.inkMid),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_subjectEditHexes.length, (i) {
                      final hex = _subjectEditHexes[i];
                      final color = _parseColor(hex);
                      final isSelected = selectedHex.toUpperCase() == hex.toUpperCase();
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedHex = hex;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.accent : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TemariButton(
                          label: 'Cancel',
                          variant: TemariButtonVariant.secondary,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TemariButton(
                          label: 'Save',
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            final updatedSubject = subject.copyWith(
                              name: name,
                              colorHex: selectedHex,
                              updatedAt: DateTime.now().toUtc(),
                            );
                            
                            await ref.read(subjectRepositoryProvider).save(updatedSubject);
                            
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Future<void> _generateFlashcards(String combinedText, String lang) async {
    if (combinedText.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _genStatus = 'Crafting study cards...';
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final hive = ref.read(hiveServiceProvider);
      
      // Request robust flashcards
      final cardsData = await gemini.generateFlashcards(
        content: combinedText,
        language: lang,
        count: 8,
      );

      if (cardsData.isEmpty) {
        throw Exception('No review cards returned.');
      }

      int count = 0;
      for (final raw in cardsData) {
        final q = raw['question'] ?? '';
        final a = raw['answer'] ?? '';
        if (q.isNotEmpty && a.isNotEmpty) {
          final flashcard = Flashcard.create(
            userId: hive.notes.firstOrNull?.userId ?? 'local',
            noteId: 'subject-aggregated',
            subjectId: widget.subjectId,
            question: q,
            answer: a,
          );
          await hive.upsertFlashcard(flashcard);
          count++;
        }
      }

      ref.read(hiveTickProvider.notifier).state++;
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated $count new study cards!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation issue: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _genStatus = null;
        });
      }
    }
  }



  void _showAddDialog() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  'Add Study Materials',
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Record lectures, capture textbook slides, or upload documents directly to this subject.',
                  style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                ),
                const SizedBox(height: 20),
                _buildActionTile(
                  icon: Icons.mic_none_rounded,
                  color: AppColors.accent,
                  title: 'Record Audio Lecture',
                  subtitle: 'Transcribe class discussions on the fly.',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/note/voice?subjectId=${widget.subjectId}');
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.camera_alt_outlined,
                  color: AppColors.accent,
                  title: 'Snap Note Scan',
                  subtitle: 'OCR analyze blackboards or formulas.',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/note/photo?subjectId=${widget.subjectId}&immediate=true');
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  color: AppColors.error,
                  title: 'Import PDF Textbook',
                  subtitle: 'Upload lecture slides or assign syllabus.',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/note/pdf?subjectId=${widget.subjectId}');
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.edit_note_rounded,
                  color: AppColors.inkMid,
                  title: 'Create Text Summary',
                  subtitle: 'Type custom bullet points manually.',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/note/text?subjectId=${widget.subjectId}');
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.style_outlined,
                  color: Colors.teal,
                  title: 'Add Flashcard Manually',
                  subtitle: 'Manually insert a Q&A review pair.',
                  onTap: () {
                    Navigator.pop(context);
                    _showManualFlashcardDialog();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.inkLight),
          ],
        ),
      ),
    );
  }

  void _showManualFlashcardDialog() {
    final qController = TextEditingController();
    final aController = TextEditingController();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Manual Flashcard',
      pageBuilder: (context, _, __) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Study Card', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Insert a custom review question and answer pair.',
                    style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: qController,
                    decoration: InputDecoration(
                      hintText: 'Enter question...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkLight),
                      filled: true,
                      fillColor: AppColors.bgSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    maxLines: 2,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aController,
                    decoration: InputDecoration(
                      hintText: 'Enter answer explanation...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkLight),
                      filled: true,
                      fillColor: AppColors.bgSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    maxLines: 3,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TemariButton(
                          label: 'Cancel',
                          variant: TemariButtonVariant.secondary,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TemariButton(
                          label: 'Create',
                          onPressed: () async {
                            final q = qController.text.trim();
                            final a = aController.text.trim();
                            if (q.isEmpty || a.isEmpty) return;
                            
                            final hive = ref.read(hiveServiceProvider);
                            final flashcard = Flashcard.create(
                              userId: hive.notes.firstOrNull?.userId ?? 'local',
                              noteId: 'manual',
                              subjectId: widget.subjectId,
                              question: q,
                              answer: a,
                            );
                            await hive.upsertFlashcard(flashcard);
                            ref.read(hiveTickProvider.notifier).state++;
                            HapticFeedback.heavyImpact();
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
    final hive = ref.watch(hiveServiceProvider);
    
    final subject = hive.getSubject(widget.subjectId);
    final notes = hive.notesForSubject(widget.subjectId);
    final cards = hive.flashcardsForSubject(widget.subjectId);

    if (subject == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: Text('Subject details not found.')),
      );
    }

    final combinedNotesText = notes
        .map((n) => '${n.title}\n${n.aiExplanation ?? n.content}')
        .join('\n\n');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      floatingActionButton: ScaleOnPress(
        onTap: _showAddDialog,
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _parseColor(subject.colorHex),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          subject.name,
                          style: AppTextStyles.h1.copyWith(fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ScaleOnPress(
                        onTap: () => _showEditSubjectDialog(context, subject),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.inkMid),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sleek AI Study Tools Toolbar
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ScaleOnPress(
                            onTap: () => context.push('/chat-session?subjectId=${subject.id}'),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AI Tutor Chat',
                                        style: AppTextStyles.small.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ScaleOnPress(
                            onTap: () => context.push('/quiz-session?subjectId=${subject.id}'),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.quiz_outlined, color: AppColors.accent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Practice Quiz',
                                        style: AppTextStyles.small.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ScaleOnPress(
                            onTap: () => _generateFlashcards(combinedNotesText, lang),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.psychology_outlined, color: AppColors.accent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Gen Cards',
                                        style: AppTextStyles.small.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Custom sliding selector tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _activeTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: _activeTab == 0
                                    ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${AppStrings.get('notes_tab', lang)} (${notes.length})',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _activeTab == 0 ? AppColors.ink : AppColors.inkLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeTab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _activeTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: _activeTab == 1
                                    ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${AppStrings.get('flashcards_tab', lang)} (${cards.length})',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _activeTab == 1 ? AppColors.ink : AppColors.inkLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content View panels
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      // Panel 1: Notes
                      notes.isEmpty
                          ? _buildEmptyState(
                              title: 'No lectures loaded yet.',
                              subtitle: 'Quick-add audio, photo or text notes directly to this subject to start learning.',
                              ctaLabel: 'Add Note Material',
                              onCta: _showAddDialog,
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80), // extra padding for FAB offset
                              itemCount: notes.length,
                              itemBuilder: (ctx, idx) {
                                final note = notes[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GestureDetector(
                                    onLongPress: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Note?'),
                                          content: const Text('Are you sure you want to delete this study note?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await hive.deleteNote(note.id);
                                        ref.read(hiveTickProvider.notifier).state++;
                                        HapticFeedback.heavyImpact();
                                      }
                                    },
                                    child: ScaleOnPress(
                                      onTap: () => context.push('/note/${note.id}'),
                                      child: RecentNoteTile(
                                        note: note,
                                        subjectName: subject.name,
                                        onTap: () => context.push('/note/${note.id}'),
                                        subjectColor: _parseColor(subject.colorHex),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Panel 2: Flashcards
                      cards.isEmpty
                          ? _buildEmptyState(
                              title: 'No study cards created.',
                              subtitle: 'Generate them instantly using the AI Study Assistant above once notes are added, or add manually.',
                              ctaLabel: 'Add Manual Card',
                              onCta: _showManualFlashcardDialog,
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80), // FAB offset
                              itemCount: cards.length,
                              itemBuilder: (ctx, idx) {
                                final card = cards[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FlashcardRow(
                                    card: card,
                                    onDelete: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Card?'),
                                          content: const Text('Delete this Q&A flashcard permanently?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await hive.deleteFlashcard(card.id);
                                        ref.read(hiveTickProvider.notifier).state++;
                                        HapticFeedback.heavyImpact();
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),

                // Exam mode floating CTA button
                if (cards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: TemariButton(
                      label: AppStrings.get('exam_mode', lang),
                      onPressed: () => context.push('/exam/${widget.subjectId}'),
                    ),
                  ),
              ],
            ),
          ),

          // Loading HUD overlay for generating features
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3.5),
                        const SizedBox(height: 20),
                        Text(
                          'Generating AI Study Aids',
                          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _genStatus ?? 'Please wait...',
                          style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String ctaLabel,
    required VoidCallback onCta,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.bgSecondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined, color: AppColors.inkLight),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.small.copyWith(color: AppColors.inkLight, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ScaleOnPress(
            onTap: onCta,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ctaLabel,
                style: AppTextStyles.small.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive flashcard row card with tapping-expansion stateful animations.
class _FlashcardRow extends StatefulWidget {
  const _FlashcardRow({
    required this.card,
    required this.onDelete,
  });

  final Flashcard card;
  final VoidCallback onDelete;

  @override
  State<_FlashcardRow> createState() => _FlashcardRowState();
}

class _FlashcardRowState extends State<_FlashcardRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onDelete,
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.card.question,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.inkLight.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANSWER KEY:',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 9,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.card.answer,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.inkMid,
                        height: 1.4,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


