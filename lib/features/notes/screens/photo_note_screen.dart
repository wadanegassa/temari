import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:permission_handler/permission_handler.dart';

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

class PhotoNoteScreen extends ConsumerStatefulWidget {
  const PhotoNoteScreen({super.key, this.subjectId, this.immediateCapture = false});

  final String? subjectId;
  final bool immediateCapture;

  @override
  ConsumerState<PhotoNoteScreen> createState() => _PhotoNoteScreenState();
}

class _PhotoNoteScreenState extends ConsumerState<PhotoNoteScreen> {
  XFile? _file;
  String _explain = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.immediateCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pick(ImageSource.camera);
      });
    }
  }

  Future<void> _pick(ImageSource src) async {
    final settings = ref.read(settingsControllerProvider);
    final hive = ref.read(hiveServiceProvider);

    // Multimodal Pro cap checking (limit 5 for free accounts)
    final multiCount = hive.notes
        .where((n) => n.type == 'voice' || n.type == 'photo' || n.type == 'file')
        .length;

    if (!settings.isPro && multiCount >= 5) {
      HapticFeedback.vibrate();
      ProPaywallSheet.show(context);
      return;
    }

    if (src == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take snaps.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _file = pickedFile;
          _explain = '';
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera Access Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _process() async {
    final f = _file;
    if (f == null) return;
    
    setState(() {
      _busy = true;
      _explain = '';
    });

    try {
      final bytes = await f.readAsBytes();
      final gemini = ref.read(geminiServiceProvider);
      final lang = ref.read(languageProvider);
      
      final subs = ref.read(subjectsProvider);
      final sid = widget.subjectId ?? (subs.isNotEmpty ? subs.first.id : '');
      final subject = ref.read(hiveServiceProvider).getSubject(sid);
      final subjectName = subject?.name;
      final fileName = f.name;

      final stream = gemini.explainImage(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
        language: lang,
        subjectName: subjectName,
        fileName: fileName,
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
          _explain = 'AI extraction failed. Check your internet connection and try again.';
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
    
    if (sid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a subject first before saving notes.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uid = ref.read(authControllerProvider).effectiveUserId;
    final lang = ref.read(languageProvider);
    
    final note = Note.create(
      userId: uid,
      subjectId: sid,
      type: noteTypePhoto,
      title: 'Photo note ${DateTime.now().hour}:${DateTime.now().minute}',
      content: _file?.path ?? '',
      language: lang,
      localFilePath: _file?.path,
    );
    note.aiExplanation = _explain;

    final hive = ref.read(hiveServiceProvider);
    await hive.upsertNote(note);
    
    try {
      await ref.read(supabaseServiceProvider).pushUpsertNote(note);
    } catch (_) {
      // offline sync silent fail
    }

    ref.read(hiveTickProvider.notifier).state++;
    HapticFeedback.mediumImpact();

    if (mounted) {
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
                  Text(
                    AppStrings.get('quick_add_photo', lang),
                    style: AppTextStyles.h1.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_file == null) ...[
                    // Cool Scanner Viewfinder Placeholder
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CustomPaint(
                        painter: _ViewfinderBorderPainter(),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.photo_camera_outlined, color: AppColors.accent, size: 28),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'AI Capture Viewfinder',
                                style: AppTextStyles.h2.copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Snap textbooks, formulas, diagrams, or blackboard outlines. Our AI reads the pixels to construct summaries & flashcards.',
                                style: AppTextStyles.small.copyWith(color: AppColors.inkLight, height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Beautiful Trigger Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ScaleOnPress(
                            onTap: () => _pick(ImageSource.camera),
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
                                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Take Snap',
                                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ScaleOnPress(
                            onTap: () => _pick(ImageSource.gallery),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_search_rounded, color: AppColors.ink, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Import Gallery',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Captured image frame with scanning sweep line overlay
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 240,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.bgSecondary,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Image.file(
                              File(_file!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Scanner Sweep Line Animation (active when processing)
                        if (_busy)
                          const Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              child: ScannerAnimation(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actions Bar or Pulsing status
                    if (_busy) ...[
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Temari AI reading formulas & diagrams...',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Synthesizing text layers via Gemini client',
                              style: AppTextStyles.small.copyWith(color: AppColors.inkLight),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ScaleOnPress(
                              onTap: () => setState(() => _file = null),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Retake',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink, fontWeight: FontWeight.bold),
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
                                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // AI Explanation Results Box
                  if (_explain.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'EXTRACTED CONCEPTS & SUMMARY',
                          style: AppTextStyles.label.copyWith(color: AppColors.accent),
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
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.45, fontSize: 13.5),
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

/// Scanner sweep animation running a glowing line up and down.
class ScannerAnimation extends StatefulWidget {
  const ScannerAnimation({super.key});

  @override
  State<ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<ScannerAnimation>
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
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom viewfinder guides for the capturing camera preview box.
class _ViewfinderBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {

    // Corner guide variables
    const length = 20.0;
    final rPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Top-Left corner
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), rPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), rPaint);

    // Top-Right corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), rPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), rPaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), rPaint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), rPaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), rPaint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), rPaint);

    // Dotted inner rectangle
    final dPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double dashWidth = 5.0;
    const double dashSpace = 5.0;

    // Draw dashed borders slightly inset
    const inset = 16.0;

    // Top horizontal dashed line
    double startX = inset;
    while (startX < size.width - inset) {
      canvas.drawLine(Offset(startX, inset), Offset(startX + dashWidth, inset), dPaint);
      startX += dashWidth + dashSpace;
    }
    // Bottom horizontal dashed line
    startX = inset;
    while (startX < size.width - inset) {
      canvas.drawLine(Offset(startX, size.height - inset), Offset(startX + dashWidth, size.height - inset), dPaint);
      startX += dashWidth + dashSpace;
    }
    // Left vertical dashed line
    double startY = inset;
    while (startY < size.height - inset) {
      canvas.drawLine(Offset(inset, startY), Offset(inset, startY + dashWidth), dPaint);
      startY += dashWidth + dashSpace;
    }
    // Right vertical dashed line
    startY = inset;
    while (startY < size.height - inset) {
      canvas.drawLine(Offset(size.width - inset, startY), Offset(size.width - inset, startY + dashWidth), dPaint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
