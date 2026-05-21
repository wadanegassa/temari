import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/bootstrap_providers.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../shared/widgets/scale_on_press.dart';
import '../utils/device_save_helper.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key, this.subjectId, this.noteId});

  final String? subjectId;
  final String? noteId;

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _chatInput = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;
  String _title = 'AI Study Tutor';
  String _contextText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeContext());
  }

  void _initializeContext() {
    final hive = ref.read(hiveServiceProvider);
    if (widget.noteId != null) {
      final note = hive.getNote(widget.noteId!);
      if (note != null) {
        setState(() {
          _title = 'Tutor: ${note.title}';
          _contextText = note.aiExplanation ?? note.content;
        });
      }
    } else if (widget.subjectId != null) {
      final subject = hive.getSubject(widget.subjectId!);
      if (subject != null) {
        final notes = hive.notesForSubject(widget.subjectId!);
        final combined = notes
            .map((n) => '${n.title}\n${n.aiExplanation ?? n.content}')
            .join('\n\n');
        setState(() {
          _title = 'Tutor: ${subject.name}';
          _contextText = combined;
        });
      }
    }
  }

  @override
  void dispose() {
    _chatInput.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _chatInput.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _messages.add({'role': 'assistant', 'text': ''});
      _chatInput.clear();
      _isStreaming = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);
      final historyList = _messages.sublist(0, _messages.length - 2);

      final stream = gemini.chatAboutNote(
        noteContent: _contextText.isNotEmpty
            ? _contextText
            : 'General study query.',
        aiExplanation: 'You are helping the student study.',
        messageHistory: historyList,
        userQuestion: text,
        language: lang,
      );

      final lastIndex = _messages.length - 1;
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        if (mounted) {
          setState(() {
            _messages[lastIndex] = {
              'role': 'assistant',
              'text': buffer.toString(),
            };
          });
          _scrollToBottom();
        }
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        final lastIndex = _messages.length - 1;
        String errMsg =
            'Failed to reach AI service. Please check your internet connection.';
        if (e is GeminiException) {
          errMsg = 'AI Error: ${e.cleanMessage}';
        }
        setState(() {
          _messages[lastIndex] = {'role': 'assistant', 'text': errMsg};
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isStreaming = false);
      }
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

  void _saveChatLog() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No messages to save!')));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Temari AI Chat Session ===');
    buffer.writeln('Topic/Context: $_title');
    buffer.writeln('Date: ${DateTime.now().toLocal()}\n');
    for (final m in _messages) {
      final role = m['role'] == 'user' ? 'Student' : 'Temari';
      buffer.writeln('$role: ${m['text']}\n');
    }

    DeviceSaveHelper.saveTextFile(
      context: context,
      fileName: 'temari_chat_${DateTime.now().millisecondsSinceEpoch}.txt',
      textContent: buffer.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: ScaleOnPress(
          onTap: () => context.pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.ink,
            size: 18,
          ),
        ),
        title: Text(_title, style: AppTextStyles.h2.copyWith(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: AppColors.accent),
            tooltip: 'Save Chat Log',
            onPressed: _saveChatLog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.accent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chat with Temari',
                            style: AppTextStyles.h2.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask questions about your study content. Save the log to your device anytime.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.inkLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final isUser = m['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isUser
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isUser
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                            border: isUser
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          child: Text(
                            m['text'] ?? '',
                            style: AppTextStyles.body.copyWith(
                              color: isUser ? Colors.white : AppColors.ink,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _chatInput,
                        decoration: const InputDecoration(
                          hintText: 'Type your question...',
                          hintStyle: TextStyle(
                            color: AppColors.inkLight,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
