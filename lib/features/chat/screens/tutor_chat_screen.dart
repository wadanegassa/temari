import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/voice_service.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../settings/providers/settings_provider.dart';

enum _ChatView { chat, history }

class _ChatSession {
  _ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  List<Map<String, String>> messages;

  factory _ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] as List?) ?? const [];
    return _ChatSession(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'New section') as String,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '') as String? ?? '') ?? DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '') as String? ?? '') ?? DateTime.now().toUtc(),
      messages: rawMessages
          .map<Map<String, String>>((item) {
            final m = item as Map;
            return {
              'role': (m['role'] ?? 'user').toString(),
              'text': (m['text'] ?? '').toString(),
            };
          })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages,
      };
}

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final List<_ChatSession> _sessions = [];
  final List<Map<String, String>> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _busy = false;
  String? _activeSessionId;
  _ChatView _view = _ChatView.chat;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceServiceProvider).init().then((_) {
        ref.read(voiceServiceProvider).addStatusListener(_onSpeechStatus);
      });
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    try {
      ref.read(voiceServiceProvider).removeStatusListener(_onSpeechStatus);
    } catch (_) {}
    super.dispose();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      _isListening = status == 'listening';
    });
  }

  void _startNewSession() {
    final lang = ref.read(languageProvider);
    HapticFeedback.mediumImpact();
    final newSession = _createSession(lang, title: AppStrings.get('new_session', lang));
    setState(() {
      _sessions.insert(0, newSession);
      _activeSessionId = newSession.id;
      _messages
        ..clear()
        ..addAll(newSession.messages);
      _view = _ChatView.chat;
    });
    _saveHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _toggleVoiceInput() async {
    final voice = ref.read(voiceServiceProvider);
    if (_isListening) {
      await voice.stop();
      setState(() {
        _isListening = false;
      });
      HapticFeedback.heavyImpact();
    } else {
      final initialText = _input.text;
      setState(() {
        _isListening = true;
      });
      HapticFeedback.mediumImpact();
      try {
        await voice.startListening((text) {
          if (mounted) {
            setState(() {
              _input.text = initialText.isEmpty ? text : '$initialText $text';
              _input.selection = TextSelection.fromPosition(
                TextPosition(offset: _input.text.length),
              );
            });
          }
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available or permission denied.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _assistantGreeting(String lang) {
    return AppStrings.get('chat_greeting', lang);
  }

  Map<String, String> _assistantGreetingMessage(String lang) => {
        'role': 'assistant',
        'text': _assistantGreeting(lang),
      };

  _ChatSession _createSession(String lang, {String? title}) {
    final now = DateTime.now().toUtc();
    return _ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: title ?? AppStrings.get('new_session', lang),
      createdAt: now,
      updatedAt: now,
      messages: [_assistantGreetingMessage(lang)],
    );
  }

  String _sessionTitleFromMessages(List<Map<String, String>> messages, String lang) {
    for (final message in messages) {
      if (message['role'] != 'user') continue;
      final text = (message['text'] ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) break;
      if (text.length <= 34) return text;
      return '${text.substring(0, 34).trim()}…';
    }
    return AppStrings.get('new_session', lang);
  }

  String _sessionPreview(_ChatSession session) {
    for (var i = session.messages.length - 1; i >= 0; i--) {
      final text = (session.messages[i]['text'] ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty) {
        if (text.length <= 60) return text;
        return '${text.substring(0, 60).trim()}…';
      }
    }
    return 'No messages yet';
  }

  String _prettyModelName(String model) {
    return model
        .replaceAll('-', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          final numeric = RegExp(r'^\d+(\.\d+)?$').hasMatch(part);
          if (numeric) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }

  List<Map<String, String>> _decodeMessages(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map<Map<String, String>>((item) {
      final m = item as Map;
      return {
        'role': (m['role'] ?? 'user').toString(),
        'text': (m['text'] ?? '').toString(),
      };
    }).toList();
  }

  _ChatSession? get _activeSession {
    if (_sessions.isEmpty) return null;
    if (_activeSessionId == null) return _sessions.first;
    for (final session in _sessions) {
      if (session.id == _activeSessionId) return session;
    }
    return _sessions.first;
  }

  void _loadHistory() {
    final lang = ref.read(languageProvider);
    final loadedSessions = <_ChatSession>[];

    try {
      final hive = ref.read(hiveServiceProvider);
      final rawSessions = hive.settingsRaw['chat_sessions'] as String?;
      if (rawSessions != null && rawSessions.isNotEmpty) {
        final decoded = jsonDecode(rawSessions) as List<dynamic>;
        loadedSessions.addAll(
          decoded.map<_ChatSession>((item) {
            return _ChatSession.fromJson(Map<String, dynamic>.from(item as Map));
          }),
        );
      } else {
        final legacy = _decodeMessages(hive.settingsRaw['chat_history'] as String?);
        loadedSessions.add(
          _ChatSession(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: 'Chat history',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            messages: legacy.isNotEmpty ? legacy : [_assistantGreetingMessage(lang)],
          ),
        );
      }
    } catch (_) {
      // Recovery silent.
    }

    if (loadedSessions.isEmpty) {
      loadedSessions.add(_createSession(lang, title: 'Chat history'));
    }

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(loadedSessions);
      _activeSessionId = _sessions.first.id;
      _messages
        ..clear()
        ..addAll(_sessions.first.messages);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _saveHistory() async {
    final lang = ref.read(languageProvider);
    try {
      final hive = ref.read(hiveServiceProvider);
      final active = _activeSession;
      if (active != null) {
        active.messages = List<Map<String, String>>.from(_messages.map((m) => Map<String, String>.from(m)));
        active.updatedAt = DateTime.now().toUtc();
        if (active.title == AppStrings.get('new_session', lang) || active.title == 'New section' || active.title == 'Chat history') {
          active.title = _sessionTitleFromMessages(active.messages, lang);
        }
      }
      await hive.patchSettings({
        'chat_sessions': jsonEncode(_sessions.map((s) => s.toJson()).toList()),
        'chat_history': jsonEncode(_messages),
      });
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

  void _openAuthScreen() {
    context.go('/auth?mode=signin');
  }

  void _switchToSession(_ChatSession session) {
    setState(() {
      _activeSessionId = session.id;
      _messages
        ..clear()
        ..addAll(session.messages);
      _view = _ChatView.chat;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _deleteSession(String sessionId) {
    final wasActive = _activeSessionId == sessionId;

    setState(() {
      _sessions.removeWhere((session) => session.id == sessionId);
      if (_sessions.isEmpty) {
        final lang = ref.read(languageProvider);
        _sessions.add(_createSession(lang, title: 'Chat history'));
      }

      if (wasActive) {
        _activeSessionId = _sessions.first.id;
        _messages
          ..clear()
          ..addAll(_sessions.first.messages);
        _view = _ChatView.chat;
      } else if (_activeSessionId != null && !_sessions.any((session) => session.id == _activeSessionId)) {
        _activeSessionId = _sessions.first.id;
        _messages
          ..clear()
          ..addAll(_sessions.first.messages);
      }
    });

    _saveHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _clearAllHistory() {
    final lang = ref.read(languageProvider);
    HapticFeedback.mediumImpact();
    setState(() {
      _sessions
        ..clear()
        ..add(_createSession(lang, title: 'Chat history'));
      _activeSessionId = _sessions.first.id;
      _messages
        ..clear()
        ..addAll(_sessions.first.messages);
      _view = _ChatView.chat;
    });
    _saveHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _syncActiveSession({String? title}) {
    final lang = ref.read(languageProvider);
    final active = _activeSession;
    if (active == null) return;
    active.messages = List<Map<String, String>>.from(_messages.map((m) => Map<String, String>.from(m)));
    active.updatedAt = DateTime.now().toUtc();
    active.title = title ?? _sessionTitleFromMessages(active.messages, lang);
  }

  Future<void> _copyText(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;

    final lang = ref.read(languageProvider);
    final settings = ref.read(settingsControllerProvider);
    final isPro = settings.isPro;
    final userMsgCount = _messages.where((m) => m['role'] == 'user').length;

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

    final trimmed = text.trim();
    setState(() {
      _messages.add({'role': 'user', 'text': trimmed});
      _messages.add({'role': 'assistant', 'text': ''});
      _input.clear();
      _busy = true;
      _view = _ChatView.chat;
      _syncActiveSession(title: _sessionTitleFromMessages(_messages, lang));
    });

    HapticFeedback.lightImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final gemini = ref.read(geminiServiceProvider);
      final historyList = _messages.sublist(0, _messages.length - 2);

      final stream = gemini.generalChatStream(
        messageHistory: historyList,
        userQuestion: trimmed,
        language: lang,
      );

      final lastIndex = _messages.length - 1;
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        if (mounted) {
          setState(() {
            _messages[lastIndex] = {'role': 'assistant', 'text': buffer.toString()};
            _syncActiveSession();
          });
          _scrollToBottom();
        }
      }
      HapticFeedback.mediumImpact();
    } catch (error) {
      final lastIndex = _messages.length - 1;
      if (mounted) {
        var errorMessage = 'AI is temporarily unavailable. Please check your Gemini configuration and try again.';
        if (error is StateError &&
            error.message.contains('Gemini API key is not configured')) {
          errorMessage = 'AI is not configured yet. Add your Gemini API key in assets/dotenv or .env, then restart the app.';
        } else if (error is GeminiException) {
          errorMessage = 'AI Error: ${error.cleanMessage}';
        } else if (error is SocketException || error is HandshakeException) {
          errorMessage = 'Network connection failed. Please check your internet and try again.';
        }
        setState(() {
          _messages[lastIndex] = {
            'role': 'assistant',
            'text': errorMessage,
          };
          _syncActiveSession();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
        await _saveHistory();
        _scrollToBottom();
      }
    }
  }

  Widget _buildHeader(String lang) {
    return Container(
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
                child: const Icon(Icons.smart_toy_rounded, color: AppColors.accent, size: 24),
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
                  'Online · ${_prettyModelName(ref.watch(settingsControllerProvider).aiModel)}',
                  style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.get('new_session', lang),
            icon: const Icon(Icons.add_comment_rounded, color: AppColors.accent, size: 22),
            onPressed: _startNewSession,
          ),
          IconButton(
            tooltip: 'History',
            icon: Icon(
              Icons.history_rounded,
              color: _view == _ChatView.history ? AppColors.accent : AppColors.inkLight,
            ),
            onPressed: () {
              setState(() {
                _view = _view == _ChatView.history ? _ChatView.chat : _ChatView.history;
              });
            },
          ),
          IconButton(
            tooltip: 'Sign In',
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.inkLight, size: 24),
            onPressed: _openAuthScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(List<String> suggestions, String lang) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: _messages.length,
            itemBuilder: (ctx, idx) {
              final m = _messages[idx];
              final isUser = m['role'] == 'user';
              final text = (m['text'] ?? '').trim();
              final isLoadingBubble = !isUser && idx == _messages.length - 1 && _busy && text.isEmpty;

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.white : AppColors.accentSoft.withValues(alpha: 0.4),
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
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: isUser ? 0 : 26, top: 0),
                        child: isUser
                            ? Text(
                                text,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 14,
                                  color: AppColors.ink,
                                  height: 1.45,
                                ),
                              )
                            : (isLoadingBubble
                                ? Text(
                                    AppStrings.get('chat_thinking', lang),
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 14,
                                      color: AppColors.inkLight,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: text,
                                    selectable: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: AppTextStyles.body.copyWith(
                                        fontSize: 14,
                                        color: AppColors.ink,
                                        height: 1.45,
                                      ),
                                      listBullet: AppTextStyles.body.copyWith(
                                        fontSize: 14,
                                        color: AppColors.ink,
                                      ),
                                      code: const TextStyle(
                                        fontFamily: 'monospace',
                                        backgroundColor: AppColors.bgSecondary,
                                        color: AppColors.accent,
                                        fontSize: 13,
                                      ),
                                      codeblockPadding: const EdgeInsets.all(8),
                                      codeblockDecoration: BoxDecoration(
                                        color: AppColors.bgSecondary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )),
                      ),
                      if (!isUser && text.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: -10,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Copy',
                            onPressed: () => _copyText(text),
                            icon: const Icon(Icons.copy_rounded, color: AppColors.inkLight, size: 18),
                          ),
                        ),
                    ],
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
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini is generating a response...',
                  style: AppTextStyles.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
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
        _buildComposer(lang),
      ],
    );
  }

  Widget _buildHistoryView(String lang) {
    final sessions = [..._sessions]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.get('chat_history_title', lang),
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _startNewSession,
                icon: const Icon(Icons.add_comment_rounded, size: 18, color: AppColors.accent),
                label: Text(AppStrings.get('new_session', lang), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: sessions.isEmpty ? null : _clearAllHistory,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text(AppStrings.get('clear_all', lang)),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.get('no_history', lang),
                    style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = session.id == _activeSessionId;
                    return Dismissible(
                      key: ValueKey(session.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded, color: AppColors.error),
                      ),
                      onDismissed: (_) => _deleteSession(session.id),
                      child: ScaleOnPress(
                        onTap: () => _switchToSession(session),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.accentSoft.withValues(alpha: 0.45) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.accent : AppColors.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.forum_rounded,
                                  color: isActive ? Colors.white : AppColors.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            session.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentSoft,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Current',
                                              style: AppTextStyles.label.copyWith(color: AppColors.accent, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _sessionPreview(session),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.small.copyWith(color: AppColors.inkLight, height: 1.4),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${session.messages.length} messages',
                                          style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                                        ),
                                        Text(
                                          '${session.updatedAt.toLocal()}'.split('.').first,
                                          style: AppTextStyles.label.copyWith(color: AppColors.inkLight),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Copy transcript',
                                          onPressed: () => _copyText(
                                            session.messages.map((m) => '${m['role']}: ${m['text']}').join('\n\n'),
                                          ),
                                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.inkLight),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildComposer(lang),
      ],
    );
  }

  Widget _buildComposer(String lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: _isListening ? AppColors.error : AppColors.border,
                  width: _isListening ? 1.5 : 1.0,
                ),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: _send,
                      style: AppTextStyles.body.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : AppStrings.get('chat_input_hint', lang),
                        hintStyle: TextStyle(
                          color: _isListening ? AppColors.error : AppColors.inkLight,
                          fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  ScaleOnPress(
                    onTap: _toggleVoiceInput,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isListening ? AppColors.errorSoft : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening ? AppColors.error : AppColors.inkLight,
                        size: 20,
                      ),
                    ),
                  ),
                ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final suggestions = lang == 'am' 
      ? ['ስለ ቢግ ኦ ኖቴሽን አስረዳኝ', 'የኢትዮጵያ ታሪክ ቁልፍ ቀናት', 'ፎቶሲንተሲስን በቀላሉ አስረዳኝ', 'ለፈተና እንዴት በብቃት ማጥናት እችላለሁ?', 'የፊዚክስ ጥናት እቅድ አውጣልኝ']
      : (lang == 'om' ? ['Waa\'ee Big O naaf ibsi', 'Guyyoota ijoo seenaa Itoophiyaa', 'Fotosintesis salphaatti naaf ibsi', 'Akkamitti qorumsaaf qophaa\'uun danda\'ama?', 'Wixinee qorannoo fiiziksii naaf qopheessi']
      : ['Explain Big O notation', 'Ethiopian History key dates', 'Explain Photosynthesis simply', 'How to study for finals effectively?', 'Draft a physics research outline']);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(lang),
            Expanded(
              child: _view == _ChatView.history ? _buildHistoryView(lang) : _buildChatView(suggestions, lang),
            ),
          ],
        ),
      ),
    );
  }
}
