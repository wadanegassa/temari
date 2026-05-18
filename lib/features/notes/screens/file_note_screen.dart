import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../subjects/providers/subjects_provider.dart';

class FileNoteScreen extends ConsumerStatefulWidget {
  const FileNoteScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  ConsumerState<FileNoteScreen> createState() => _FileNoteScreenState();
}

class _FileNoteScreenState extends ConsumerState<FileNoteScreen> {
  List<int>? _bytes;
  String? _name;
  String _explain = '';
  var _busy = false;

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final f = r?.files.single;
    if (f?.bytes == null) return;
    if (f!.bytes!.length > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF must be under 10 MB')),
      );
      return;
    }
    setState(() {
      _bytes = f.bytes;
      _name = f.name;
    });
  }

  Future<void> _process() async {
    final b = _bytes;
    if (b == null) return;
    setState(() => _busy = true);
    final gemini = ref.read(geminiServiceProvider);
    final lang = ref.read(languageProvider);
    _explain = '';
    try {
      final stream = gemini.explainPdf(
        pdfBytes: b,
        language: lang,
      );
      await for (final c in stream) {
        _explain += c;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        final lang = ref.read(languageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('retry', lang))),
        );
      }
    }
    setState(() => _busy = false);
  }

  Future<void> _save() async {
    final subs = ref.read(subjectsProvider);
    final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');
    if (sid.isEmpty || _bytes == null) return;
    final uid = ref.read(authControllerProvider).effectiveUserId;
    final lang = ref.read(languageProvider);
    final n = Note.create(
      userId: uid,
      subjectId: sid,
      type: noteTypeFile,
      title: _name ?? 'PDF',
      content: 'PDF · ${_bytes!.length} bytes',
      language: lang,
    );
    n.aiExplanation = _explain;
    await ref.read(hiveServiceProvider).upsertNote(n);
    await ref.read(supabaseServiceProvider).pushUpsertNote(n);
    ref.read(hiveTickProvider.notifier).state++;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(AppStrings.get('quick_add_file', lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TemariButton(label: 'Pick PDF', onPressed: _pick),
          if (_name != null) Text(_name!, style: AppTextStyles.body),
          if (_bytes != null) ...[
            const SizedBox(height: 12),
            TemariButton(
              label: AppStrings.get('process_ai', lang),
              onPressed: _busy ? null : _process,
            ),
          ],
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
