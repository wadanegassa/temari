import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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

class PhotoNoteScreen extends ConsumerStatefulWidget {
  const PhotoNoteScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  ConsumerState<PhotoNoteScreen> createState() => _PhotoNoteScreenState();
}

class _PhotoNoteScreenState extends ConsumerState<PhotoNoteScreen> {
  XFile? _file;
  String _explain = '';
  var _busy = false;

  Future<void> _pick(ImageSource src) async {
    final p = ImagePicker();
    _file = await p.pickImage(source: src, maxWidth: 1600, imageQuality: 85);
    setState(() {});
  }

  Future<void> _process() async {
    final f = _file;
    if (f == null) return;
    setState(() => _busy = true);
    final bytes = await f.readAsBytes();
    final gemini = ref.read(geminiServiceProvider);
    final lang = ref.read(languageProvider);
    final stream = gemini.explainImage(
      imageBytes: bytes,
      mimeType: 'image/jpeg',
      language: lang,
    );
    _explain = '';
    await for (final c in stream) {
      _explain += c;
      setState(() {});
    }
    setState(() => _busy = false);
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
      type: noteTypePhoto,
      title: 'Photo note',
      content: _file?.path ?? '',
      language: lang,
      localFilePath: _file?.path,
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
      appBar: AppBar(title: Text(AppStrings.get('quick_add_photo', lang))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              TemariButton(
                expanded: false,
                label: 'Camera',
                onPressed: () => _pick(ImageSource.camera),
              ),
              const SizedBox(width: 12),
              TemariButton(
                expanded: false,
                label: 'Gallery',
                variant: TemariButtonVariant.secondary,
                onPressed: () => _pick(ImageSource.gallery),
              ),
            ],
          ),
          if (_file != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(_file!.path), height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
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
