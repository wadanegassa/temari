import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../settings/providers/settings_provider.dart';

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    try {
      final hive = ref.read(hiveServiceProvider);
      final raw = hive.settingsRaw['chat_history'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        setState(() {
          _messages.addAll(
            decoded.map<Map<String, String>>((item) {
              final m = item as Map;
              return {
                'role': (m['role'] ?? 'user').toString(),
                'text': (m['text'] ?? '').toString(),
              };
            }),
          );
        });
      }
    } catch (_) {
      // recovery silent
    }

    if (_messages.isEmpty) {
      _messages.add({
        'role': 'assistant',
        'text': 'Hello! I am Temari, your expert Ethiopian university tutor. Ask me any academic questions, textbook concepts, formulas, or general exam preparations. How can I help you excel today?'
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _saveHistory() async {
    try {
      final hive = ref.read(hiveServiceProvider);
      final encoded = jsonEncode(_messages);
      await hive.patchSettings({'chat_history': encoded});
    } catch (_) {
      // silent recover
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    
    final settings = ref.read(settingsControllerProvider);
    final isPro = settings.isPro;
    final userMsgCount = _messages.where((m) => m['role'] == 'user').length;

    // Trigger premium limitations (5 free queries for standard users)
    if (!isPro && userMsgCount >= 5) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free trial limit of 5 general questions reached. Upgrade to Pro in Settings for unlimited tutoring!'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _messages.add({'role': 'assistant', 'text': ''});
      _input.clear();
      _busy = true;
    });

    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);

      // Extract raw messages excluding the empty one at the end
      final historyList = _messages.sublist(0, _messages.length - 2);

      final stream = gemini.generalChatStream(
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
            _messages[lastIndex] = {'role': 'assistant', 'text': buffer.toString()};
          });
          _scrollToBottom();
        }
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      final lastIndex = _messages.length - 1;
      if (mounted) {
        setState(() {
          _messages[lastIndex] = {
            'role': 'assistant',
            'text': 'I encountered a connection timeout. Please check your internet connection. Temari stands ready to assist you offline!'
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
        _saveHistory();
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Reset Chat Log', style: AppTextStyles.h2),
        content: Text('Are you sure you want to clear your learning conversation with Temari? This cannot be undone.', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.inkLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add({
                  'role': 'assistant',
                  'text': 'Chat reset. Hello! I am Temari, your expert Ethiopian university tutor. Ask me any academic questions, textbook concepts, formulas, or general exam preparations. How can I help you excel today?'
                });
              });
              await _saveHistory();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Explain Big O notation 💡',
      'Ethiopian History key dates 🏛️',
      'Explain Photosynthesis simply 🌱',
      'How to study for finals effectively? 🧠',
      'Draft a physics research outline 📝'
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Custom chatbot header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 24),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Temari AI Tutor',
                          style: TextStyle(
                            fontFamily: 'CabinetGrotesk',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Online · Ask anything',
                          style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkLight),
                    onPressed: _clearChat,
                  ),
                ],
              ),
            ),

            // Messages chat history viewport
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (ctx, idx) {
                  final m = _messages[idx];
                  final isUser = m['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.white : AppColors.accentSoft.withOpacity(0.4),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: Border.all(
                          color: isUser ? AppColors.border : AppColors.accentSoft,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        m['text'] ?? '',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_busy) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Temari AI is formulating response...',
                      style: AppTextStyles.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],

            // Horizontal suggestions cards
            if (!_busy)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: suggestions.length,
                  itemBuilder: (ctx, idx) {
                    final sug = suggestions[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ScaleOnPress(
                        onTap: () => _send(sug),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            sug,
                            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),

            // Bottom Input Section with modern floating capsule
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _input,
                        onSubmitted: _send,
                        style: AppTextStyles.body.copyWith(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Ask Temari your question...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ScaleOnPress(
                    onTap: () => _send(_input.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
