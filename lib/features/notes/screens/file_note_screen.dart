import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/models/sync_task.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/pro_paywall_sheet.dart';
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
  bool _busy = false;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pick() async {
    final settings = ref.read(settingsControllerProvider);
    final hive = ref.read(hiveServiceProvider);

    // Multimodal Pro limit cap checking (limit 5 total for free accounts)
    final multiCount = hive.notes
        .where(
          (n) => n.type == 'voice' || n.type == 'photo' || n.type == 'file',
        )
        .length;

    if (!settings.isPro && multiCount >= 5) {
      HapticFeedback.vibrate();
      ProPaywallSheet.show(context);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      final file = result?.files.single;
      if (file?.bytes == null) return;

      if (file!.bytes!.length > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Document exceeds limit. Please upload a PDF under 10 MB.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() {
        _bytes = file.bytes;
        _name = file.name;
        _explain = '';
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _process() async {
    final b = _bytes;
    if (b == null) return;

    setState(() {
      _busy = true;
      _explain = '';
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);

      final subs = ref.read(subjectsProvider);
      final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');
      final subject = ref.read(hiveServiceProvider).getSubject(sid);
      final subjectName = subject?.name;

      final stream = gemini.explainPdf(
        pdfBytes: b,
        language: lang,
        subjectName: subjectName,
        fileName: _name,
      );

      await for (final chunk in stream) {
        if (mounted) {
          setState(() {
            _explain += chunk;
          });
        }
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (mounted) {
        setState(() {
          _explain =
              'AI extraction failed. Check your internet connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final subs = ref.read(subjectsProvider);
    final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');

    if (sid.isEmpty || _bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create a subject first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    String? localPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      localPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${_name ?? "document.pdf"}';
      final file = File(localPath);
      await file.writeAsBytes(_bytes!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file locally: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() {
        _busy = false;
      });
      return;
    }

    final uid = ref.read(authControllerProvider).effectiveUserId;
    final lang = ref.read(languageProvider);
    final gemini = ref.read(geminiServiceProvider);
    final parsed = gemini.normalizeExplanationByLanguage(
      text: _explain,
      requestedLanguage: lang,
    );

    final note = Note.create(
      userId: uid,
      subjectId: sid,
      type: noteTypeFile,
      title: _name ?? 'PDF document note',
      content: 'PDF · ${_formatSize(_bytes!.length)}',
      language: lang,
      localFilePath: localPath,
    );
    note.aiExplanation = parsed[lang] ?? _explain;
    note.aiExplanationByLang = parsed;

    final hive = ref.read(hiveServiceProvider);
    await hive.upsertNote(note);
    await hive.addSyncTask(SyncTask.create(
      action: 'upsert',
      entityType: 'note',
      entityId: note.id,
      payload: note.toJson(),
    ));

    ref.read(hiveTickProvider.notifier).state++;
    unawaited(ref.read(syncServiceProvider).syncAll());
    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        _busy = false;
      });
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (matching snap/voice screens)
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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    AppStrings.get('quick_add_file', lang),
                    style: AppTextStyles.h1.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_bytes == null) ...[
                    // Inactive state - dashed upload cards
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CustomPaint(
                        painter: _DashedZonePainter(),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  color: AppColors.accent,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Import PDF Document',
                                style: AppTextStyles.h2.copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add syllabi, lecture slides, assignments, or complete textbook notes. Max limit 10 MB.',
                                style: AppTextStyles.small.copyWith(
                                  color: AppColors.inkLight,
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pick CTA Button
                    ScaleOnPress(
                      onTap: _pick,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.file_open_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Choose PDF Document',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Active State - Gorgeous selected PDF card with sweep scan overlay
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppColors.error,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name ?? 'Document.pdf',
                                      style: AppTextStyles.h3.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatSize(_bytes!.length),
                                      style: AppTextStyles.small.copyWith(
                                        color: AppColors.inkLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Scanner Sweep Line Animation (active when processing)
                        if (_busy)
                          const Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              child: _ScannerSweepAnimation(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actions Row or Pulsing status
                    if (_busy) ...[
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Temari AI digesting document vectors...',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Structuring lecture layout definitions',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.inkLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ScaleOnPress(
                              onTap: () => setState(() {
                                _bytes = null;
                                _name = null;
                                _explain = '';
                              }),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Change File',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ScaleOnPress(
                              onTap: _process,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  AppStrings.get('process_ai', lang),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // AI Explanation results box
                  if (_explain.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI TEXTBOOK EXTRACTION & CONCEPTS',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _explain,
                        style: AppTextStyles.bodyMedium.copyWith(
                          height: 1.45,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TemariButton(
                      label: AppStrings.get('save', lang),
                      onPressed: _save,
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom sweep scanner animation line.
class _ScannerSweepAnimation extends StatefulWidget {
  const _ScannerSweepAnimation();

  @override
  State<_ScannerSweepAnimation> createState() => _ScannerSweepAnimationState();
}

class _ScannerSweepAnimationState extends State<_ScannerSweepAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2000),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, child) {
        return FractionallySizedBox(
          widthFactor: 1.0,
          child: Align(
            alignment: Alignment(0, _controller.value * 2 - 1),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.accent,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGlow.withValues(alpha: 0.8),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom dashed painter for the file zone.
class _DashedZonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    const double inset = 16.0;

    // Corner guides
    const length = 20.0;
    final rPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-Left corner
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), rPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), rPaint);

    // Top-Right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - length, 0),
      rPaint,
    );
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), rPaint);

    // Bottom-Left corner
    canvas.drawLine(
      Offset(0, size.height),
      Offset(length, size.height),
      rPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - length),
      rPaint,
    );

    // Bottom-Right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - length, size.height),
      rPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - length),
      rPaint,
    );

    // Draw dashed borders inset
    // Top line
    double startX = inset;
    while (startX < size.width - inset) {
      canvas.drawLine(
        Offset(startX, inset),
        Offset(startX + dashWidth, inset),
        dPaint,
      );
      startX += dashWidth + dashSpace;
    }
    // Bottom line
    startX = inset;
    while (startX < size.width - inset) {
      canvas.drawLine(
        Offset(startX, size.height - inset),
        Offset(startX + dashWidth, size.height - inset),
        dPaint,
      );
      startX += dashWidth + dashSpace;
    }
    // Left line
    double startY = inset;
    while (startY < size.height - inset) {
      canvas.drawLine(
        Offset(inset, startY),
        Offset(inset, startY + dashWidth),
        dPaint,
      );
      startY += dashWidth + dashSpace;
    }
    // Right line
    startY = inset;
    while (startY < size.height - inset) {
      canvas.drawLine(
        Offset(size.width - inset, startY),
        Offset(size.width - inset, startY + dashWidth),
        dPaint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
