import 'dart:async';
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
import '../../../shared/models/note.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/temari_text_field.dart';
import '../../../shared/widgets/pro_paywall_sheet.dart';
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
  bool _isPredicting = false;
  bool _showRawContent = false;

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
      final buffer = StringBuffer();
      final stream = gemini.explainText(
        content: n.content,
        language: code,
      );

      await for (final chunk in stream) {
        buffer.write(chunk);
        // Live updates
        n.aiExplanation = buffer.toString();
        setState(() {});
      }

      n.aiExplanationByLang![code] = buffer.toString();
      n.aiExplanation = buffer.toString();
      n.language = code;
      await hive.upsertNote(n);
      await ref.read(supabaseServiceProvider).pushUpsertNote(n);

      ref.read(hiveTickProvider.notifier).state++;
    } catch (_) {
      // safe recovery
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
              'Successfully generated ${cards.length} flashcards! 🎉',
              style: AppTextStyles.small.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } catch (_) {
      // safe fallback
    } finally {
      setState(() => _isGeneratingCards = false);
    }
  }

  Future<void> _loadPredictedQuestions() async {
    final hive = ref.read(hiveServiceProvider);
    final n = hive.getNote(widget.noteId);
    if (n == null) return;

    setState(() => _isPredicting = true);

    try {
      final lang = ref.read(languageProvider);
      final gemini = ref.read(geminiServiceProvider);
      final qs = await gemini.predictExamQuestions(
        content: n.aiExplanation ?? n.content,
        language: lang,
      );

      n.predictedQuestions = qs;
      await hive.upsertNote(n);
      ref.read(hiveTickProvider.notifier).state++;
    } catch (_) {
    } finally {
      setState(() => _isPredicting = false);
    }
  }

  void _openChatOverlay(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteChatSheet(note: note, language: _displayLang),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(hiveTickProvider);
    final lang = ref.watch(languageProvider);
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

    final explanation = n.aiExplanationByLang?[_displayLang] ?? n.aiExplanation ?? '';

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
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: AppTextStyles.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
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
                  // Action pills row (Mind Map, Flashcards, Ask Temari)
                  Row(
                    children: [
                      Expanded(
                        child: _ActionPill(
                          label: 'Mind Map 🌿',
                          color: AppColors.accent,
                          onTap: () {
                            final settings = ref.read(settingsControllerProvider);
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
                          label: 'Ask Temari 💬',
                          color: AppColors.inkMid,
                          onTap: () => _openChatOverlay(n),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ActionPill(
                    label: _isGeneratingCards ? 'Generating Flashcards...' : 'Generate Review Flashcards 🎴',
                    color: AppColors.success,
                    onTap: _isGeneratingCards ? null : _generateFlashcards,
                  ),
                  const SizedBox(height: 24),

                  // Language selector chip row
                  Row(
                    children: [
                      Text(
                        'EXPLANATION LANGUAGE',
                        style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
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
                            const Icon(Icons.auto_awesome_outlined, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'AI Deep Explanation',
                              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isExplaining && explanation.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(color: AppColors.accent),
                            ),
                          )
                        else
                          Text(
                            explanation.isNotEmpty ? explanation : 'No AI explanation generated yet.',
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
                    onTap: () => setState(() => _showRawContent = !_showRawContent),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showRawContent ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                            color: AppColors.inkMid,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Show Original Material',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkMid, fontSize: 13),
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
                        style: AppTextStyles.small.copyWith(color: AppColors.inkMid, height: 1.5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Predicted Exam Questions
                  Row(
                    children: [
                      Text(
                        'PREDICTED EXAM QUESTIONS',
                        style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                      ),
                      const Spacer(),
                      if (n.predictedQuestions == null && !_isPredicting)
                        ScaleOnPress(
                          onTap: _loadPredictedQuestions,
                          child: Text(
                            'Predict ✦',
                            style: AppTextStyles.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isPredicting)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.accent)))
                  else if (n.predictedQuestions != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: n.predictedQuestions!
                            .map(
                              (q) => Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
                                    Expanded(
                                      child: Text(
                                        q,
                                        style: AppTextStyles.small.copyWith(color: AppColors.inkMid, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Tap Predict to extract likely university exam questions.',
                        style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
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
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
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
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
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
    final hive = ref.read(hiveServiceProvider);
    final settings = ref.read(settingsControllerProvider);
    if (!settings.isPro && _messages.where((m) => m['role'] == 'user').length >= 5) {
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
          _messages[lastIndex] = {'role': 'assistant', 'text': buffer.toString()};
        });
        _scrollToBottom();
      }
      HapticFeedback.lightImpact();
    } catch (_) {
      final lastIndex = _messages.length - 1;
      setState(() {
        _messages[lastIndex] = {'role': 'assistant', 'text': 'Sorry, I failed to get an answer. Please check your internet connection.'};
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
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        children: [
          // Drag indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Ask Temari', style: AppTextStyles.h2.copyWith(fontSize: 16)),
              const Spacer(),
              ScaleOnPress(
                onTap: () => Navigator.pop(context),
                child: Text('Close', style: AppTextStyles.small.copyWith(color: AppColors.inkMid, fontWeight: FontWeight.bold)),
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
                      style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
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
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: isUser ? const Radius.circular(14) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(14),
                            ),
                            border: isUser ? null : Border.all(color: AppColors.border),
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
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.inkLight),
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
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
