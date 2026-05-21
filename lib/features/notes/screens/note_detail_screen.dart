import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/gemini_service.dart';
import '../../../shared/models/flashcard.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/pro_paywall_sheet.dart';
import '../../../shared/utils/device_save_helper.dart';
import '../../settings/providers/settings_provider.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late final TextEditingController _titleController = TextEditingController();
  String _displayLang = 'en';
  bool _isExplaining = false;
  bool _isGeneratingCards = false;
  bool _showRawContent = false;

  String _mimeTypeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.heic')) return 'image/heic';
    if (p.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  String _fallbackSourceForRegeneration(Note n) {
    final byLang = n.aiExplanationByLang;
    if (byLang != null && byLang.isNotEmpty) {
      return byLang.values.first;
    }
    if ((n.aiExplanation ?? '').trim().isNotEmpty) {
      return n.aiExplanation!;
    }
    return n.content;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _switchLanguage(String code) async {
    final hive = ref.read(hiveServiceProvider);
    final n = hive.getNote(widget.noteId);
    if (n == null) return;

    n.aiExplanationByLang ??= {};
    if (n.aiExplanationByLang!.containsKey(code)) {
      setState(() {
        _displayLang = code;
      });
      return;
    }

    // Call Gemini to explain in the target language if not cached
    setState(() {
      _displayLang = code;
      _isExplaining = true;
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final subjectName = hive.getSubject(n.subjectId)?.name;
      final buffer = StringBuffer();
      late final Stream<String> stream;

      if (n.type == noteTypeFile && n.localFilePath != null) {
        final f = File(n.localFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          stream = gemini.explainPdf(
            pdfBytes: bytes,
            language: code,
            subjectName: subjectName,
            fileName: n.title,
          );
        } else {
          stream = gemini.explainText(
            content: _fallbackSourceForRegeneration(n),
            language: code,
            subjectName: subjectName,
          );
        }
      } else if (n.type == noteTypePhoto && n.localFilePath != null) {
        final f = File(n.localFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          stream = gemini.explainImage(
            imageBytes: bytes,
            mimeType: _mimeTypeFromPath(n.localFilePath!),
            language: code,
            subjectName: subjectName,
            fileName: n.title,
          );
        } else {
          stream = gemini.explainText(
            content: _fallbackSourceForRegeneration(n),
            language: code,
            subjectName: subjectName,
          );
        }
      } else {
        stream = gemini.explainText(
          content: n.content,
          language: code,
          subjectName: subjectName,
        );
      }

      await for (final chunk in stream) {
        buffer.write(chunk);
        // Live updates
        n.aiExplanation = buffer.toString();
        setState(() {});
      }

      final normalized = gemini.normalizeExplanationByLanguage(
        text: buffer.toString(),
        requestedLanguage: code,
      );
      n.aiExplanationByLang!.addAll(normalized);
      n.aiExplanation = buffer.toString();
      n.language = code;
      await hive.upsertNote(n);
      await ref.read(supabaseServiceProvider).pushUpsertNote(n);

      ref.read(hiveTickProvider.notifier).state++;
    } catch (e) {
      if (mounted) {
        String msg = 'AI explanation requires an internet connection.';
        if (e is GeminiException) {
          msg = 'AI Error: ${e.cleanMessage}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isExplaining = false);
    }
  }

  Future<void> _generateFlashcards() async {
    final hive = ref.read(hiveServiceProvider);
    final settings = ref.read(settingsControllerProvider);

    // Check Free limits: Max 40 flashcards total
    if (!settings.isPro && hive.flashcards.length >= 40) {
      ProPaywallSheet.show(context);
      return;
    }

    final n = hive.getNote(widget.noteId);
    if (n == null) return;

    setState(() => _isGeneratingCards = true);
    HapticFeedback.mediumImpact();

    try {
      final lang = ref.read(languageProvider);
      final gemini = ref.read(geminiServiceProvider);

      final cards = await gemini.generateFlashcards(
        content: n.aiExplanation ?? n.content,
        language: lang,
        count: 8,
      );

      for (final c in cards) {
        final f = Flashcard.create(
          userId: n.userId,
          noteId: n.id,
          subjectId: n.subjectId,
          question: c['question'] ?? 'Question',
          answer: c['answer'] ?? 'Answer',
        );
        await hive.upsertFlashcard(f);
        await ref.read(supabaseServiceProvider).pushUpsertFlashcard(f);
      }

      ref.read(hiveTickProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Successfully generated ${cards.length} flashcards!',
              style: AppTextStyles.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Flashcard generation requires an internet connection.';
        if (e is GeminiException) {
          msg = 'AI Error: ${e.cleanMessage}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isGeneratingCards = false);
    }
  }

  Future<void> _openExternal() async {
    final n = ref.read(hiveServiceProvider).getNote(widget.noteId);
    final path = n?.localFilePath;
    if (path == null) return;

    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hiveTickProvider);
    final n = ref.watch(hiveServiceProvider).getNote(widget.noteId);

    if (n == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: Text('Note not found.', style: AppTextStyles.h2)),
      );
    }

    if (_titleController.text.isEmpty) {
      _titleController.text = n.title;
      _displayLang = n.language;
    }

    final explanation =
        n.aiExplanationByLang?[_displayLang] ?? n.aiExplanation ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (No AppBar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (v) async {
                        n.title = v.trim().isEmpty ? 'Untitled Note' : v.trim();
                        await ref.read(hiveServiceProvider).upsertNote(n);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  if (n.type == noteTypeFile && n.localFilePath != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ScaleOnPress(
                              onTap: () {
                                context.push(
                                  '/pdf-viewer?filePath=${Uri.encodeComponent(n.localFilePath!)}&title=${Uri.encodeComponent(n.title)}',
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: AppColors.accent,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Read in App',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.accent,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Use built-in PDF viewer.',
                                            style: AppTextStyles.small.copyWith(
                                              color: AppColors.accent
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.launch_rounded,
                              color: AppColors.accent,
                            ),
                            tooltip: 'Open in External App',
                            onPressed: _openExternal,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.save_alt_rounded,
                              color: AppColors.accent,
                            ),
                            tooltip: 'Save PDF to Device',
                            onPressed: () async {
                              try {
                                final file = File(n.localFilePath!);
                                if (await file.exists()) {
                                  final bytes = await file.readAsBytes();
                                  if (context.mounted) {
                                    await DeviceSaveHelper.saveBinaryFile(
                                      context: context,
                                      fileName:
                                          '${n.title.replaceAll(' ', '_')}.pdf',
                                      bytes: bytes,
                                      extension: 'pdf',
                                    );
                                  }
                                } else {
                                  throw Exception('File not found locally.');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving PDF: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Action pills row (Mind Map, Flashcards, Ask Temari)
                  if (n.type != noteTypeFile) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ActionPill(
                            label: 'Mind Map',
                            color: AppColors.accent,
                            onTap: () {
                              final settings = ref.read(
                                settingsControllerProvider,
                              );
                              if (!settings.isPro) {
                                ProPaywallSheet.show(context);
                              } else {
                                context.push('/mindmap/${n.id}');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionPill(
                            label: 'Ask Temari',
                            color: AppColors.inkMid,
                            onTap: () =>
                                context.push('/chat-session?noteId=${n.id}'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _ActionPill(
                      label: 'Ask Temari',
                      color: AppColors.inkMid,
                      onTap: () => context.push('/chat-session?noteId=${n.id}'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ActionPill(
                    label: _isGeneratingCards
                        ? 'Generating Flashcards...'
                        : 'Generate Review Flashcards',
                    color: AppColors.success,
                    onTap: _isGeneratingCards ? null : _generateFlashcards,
                  ),
                  const SizedBox(height: 24),

                  // Language selector chip row
                  Row(
                    children: [
                      Text(
                        'EXPLANATION LANGUAGE',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.inkLight,
                        ),
                      ),
                      const Spacer(),
                      _LangChip(
                        code: 'en',
                        label: 'EN',
                        isSelected: _displayLang == 'en',
                        onTap: () => _switchLanguage('en'),
                      ),
                      const SizedBox(width: 6),
                      _LangChip(
                        code: 'am',
                        label: 'አማ',
                        isSelected: _displayLang == 'am',
                        onTap: () => _switchLanguage('am'),
                      ),
                      const SizedBox(width: 6),
                      _LangChip(
                        code: 'om',
                        label: 'ORO',
                        isSelected: _displayLang == 'om',
                        onTap: () => _switchLanguage('om'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // AI Explanation Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI Deep Explanation',
                                style: AppTextStyles.h3.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (explanation.isNotEmpty) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.save_alt_rounded,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Save Explanation to Device',
                                onPressed: () {
                                  DeviceSaveHelper.saveTextFile(
                                    context: context,
                                    fileName:
                                        'temari_explanation_${n.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.txt',
                                    textContent: explanation,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Delete Explanation',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Explanation?'),
                                      content: const Text(
                                        'Are you sure you want to delete this AI generated explanation?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final hive = ref.read(hiveServiceProvider);
                                    n.aiExplanationByLang?.remove(_displayLang);
                                    if (n.aiExplanationByLang?.isEmpty ??
                                        true) {
                                      n.aiExplanation = null;
                                    } else {
                                      n.aiExplanation =
                                          n.aiExplanationByLang?[_displayLang] ??
                                          n
                                              .aiExplanationByLang
                                              ?.values
                                              .firstOrNull;
                                    }
                                    await hive.upsertNote(n);
                                    await ref
                                        .read(supabaseServiceProvider)
                                        .pushUpsertNote(n);
                                    ref.read(hiveTickProvider.notifier).state++;
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isExplaining && explanation.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                              ),
                            ),
                          )
                        else
                          Text(
                            explanation.isNotEmpty
                                ? explanation
                                : 'No AI explanation generated yet.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.ink,
                              fontSize: 14.5,
                              height: 1.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Collapsible Original Content Drawer
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showRawContent = !_showRawContent),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showRawContent
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            color: AppColors.inkMid,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Show Original Material',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.inkMid,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showRawContent) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        n.content,
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.inkMid,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Interactive Quiz Card
                  Row(
                    children: [
                      Text(
                        'PRACTICE QUIZ',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test your knowledge with an AI quiz!',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Generate multiple choice questions based on this study content. Retake or export them anytime.',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.inkMid,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ScaleOnPress(
                          onTap: () => context.push(
                            '/quiz-session?noteId=${n.id}&subjectId=${n.subjectId}',
                          ),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Start Practice Quiz',
                              style: AppTextStyles.small.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                // ignore: deprecated_member_use
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.code,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: isSelected ? AppColors.accent : AppColors.inkMid,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _NoteChatSheet extends ConsumerStatefulWidget {
  const _NoteChatSheet({required this.note, required this.language});

  final Note note;
  final String language;

  @override
  ConsumerState<_NoteChatSheet> createState() => _NoteChatSheetState();
}

class _NoteChatSheetState extends ConsumerState<_NoteChatSheet> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _chatInput = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;

  @override
  void dispose() {
    _chatInput.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty || _isStreaming) return;

    // Free tier message limitation: Max 5 chat messages
    final settings = ref.read(settingsControllerProvider);
    if (!settings.isPro &&
        _messages.where((m) => m['role'] == 'user').length >= 5) {
      Navigator.pop(context);
      ProPaywallSheet.show(context);
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _messages.add({'role': 'assistant', 'text': ''});
      _chatInput.clear();
      _isStreaming = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final gemini = ref.read(geminiServiceProvider);
      // Keep last 6 message pairs in messageHistory
      final historyList = _messages.sublist(0, _messages.length - 2);

      final stream = gemini.chatAboutNote(
        noteContent: widget.note.content,
        aiExplanation: widget.note.aiExplanation ?? '',
        messageHistory: historyList,
        userQuestion: text,
        language: widget.language,
      );

      final lastIndex = _messages.length - 1;
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        setState(() {
          _messages[lastIndex] = {
            'role': 'assistant',
            'text': buffer.toString(),
          };
        });
        _scrollToBottom();
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      final lastIndex = _messages.length - 1;
      String errMsg =
          'I could not reach the AI service. Please check your internet connection.';
      if (e is GeminiException) {
        errMsg = 'AI Error: ${e.cleanMessage}';
      }
      setState(() {
        _messages[lastIndex] = {'role': 'assistant', 'text': errMsg};
      });
    } finally {
      setState(() => _isStreaming = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        children: [
          // Drag indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ask Temari',
                style: AppTextStyles.h2.copyWith(fontSize: 16),
              ),
              const Spacer(),
              ScaleOnPress(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.inkMid,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message history list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Ask any specific question about these study notes.',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.inkLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isUser = m['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: isUser
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              bottomRight: isUser
                                  ? Radius.zero
                                  : const Radius.circular(14),
                            ),
                            border: isUser
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            m['text'] ?? '',
                            style: AppTextStyles.body.copyWith(
                              color: isUser ? Colors.white : AppColors.ink,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Custom Input field row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _chatInput,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question about this note...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkLight,
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 13.5),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ScaleOnPress(
                onTap: _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
