import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/sync_task.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/voice_service.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/temari_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';

class TextNoteScreen extends ConsumerStatefulWidget {
  const TextNoteScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  ConsumerState<TextNoteScreen> createState() => _TextNoteScreenState();
}

class _TextNoteScreenState extends ConsumerState<TextNoteScreen> {
  final _text = TextEditingController();
  String _explain = '';
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _dictate() async {
    final v = ref.read(voiceServiceProvider);
    await v.init();
    await v.startListening((t) => _text.text = t);
  }

  Future<void> runExplain() async {
    setState(() => _busy = true);
    _explain = '';

    try {
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);

      final subs = ref.read(subjectsProvider);
      final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');
      final subject = ref.read(hiveServiceProvider).getSubject(sid);
      final subjectName = subject?.name;

      final stream = gemini.explainText(
        content: _text.text,
        language: lang,
        subjectName: subjectName,
      );
      await for (final c in stream) {
        _explain += c;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI explanation requires an internet connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    final subs = ref.read(subjectsProvider);
    final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');
    if (sid.isEmpty) return;
    final uid = ref.read(authControllerProvider).effectiveUserId;
    final lang = ref.read(languageProvider);
    final n = Note.create(
      userId: uid,
      subjectId: sid,
      type: noteTypeText,
      title: _text.text.split('\n').first,
      content: _text.text,
      language: lang,
    );
    final gemini = ref.read(geminiServiceProvider);
    final parsed = gemini.normalizeExplanationByLanguage(
      text: _explain,
      requestedLanguage: lang,
    );
    n.aiExplanation = parsed[lang] ?? _explain;
    n.aiExplanationByLang = parsed;
    await ref.read(hiveServiceProvider).upsertNote(n);
    await ref.read(hiveServiceProvider).addSyncTask(SyncTask.create(
      action: 'upsert',
      entityType: 'note',
      entityId: n.id,
      payload: n.toJson(),
    ));
    ref.read(hiveTickProvider.notifier).state++;
    unawaited(ref.read(syncServiceProvider).syncAll());
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppStrings.get('quick_add_text', lang)),
        actions: [
          IconButton(
            onPressed: _dictate,
            icon: const Icon(Icons.mic_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TemariTextField(controller: _text, hint: '…', maxLines: 12),
          const SizedBox(height: 16),
          TemariButton(
            label: AppStrings.get('explain_ai', lang),
            onPressed: _busy ? null : runExplain,
          ),
          if (_explain.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_explain, style: AppTextStyles.body),
            TemariButton(label: AppStrings.get('save', lang), onPressed: _save),
          ],
        ],
      ),
    );
  }
}
