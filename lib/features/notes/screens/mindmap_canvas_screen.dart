import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/sync_task.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/note.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../settings/providers/settings_provider.dart';

class MindMapCanvasScreen extends ConsumerStatefulWidget {
  const MindMapCanvasScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<MindMapCanvasScreen> createState() => _MindMapCanvasScreenState();
}

class _MindMapCanvasScreenState extends ConsumerState<MindMapCanvasScreen> {
  bool _isGenerating = false;
  String? _error;
  Map<String, dynamic>? _mindmapData;

  @override
  void initState() {
    super.initState();
    _loadOrGenerate();
  }

  Future<void> _loadOrGenerate() async {
    final hive = ref.read(hiveServiceProvider);
    final note = hive.getNote(widget.noteId);
    if (note == null) {
      setState(() => _error = 'Note not found.');
      return;
    }

    final lang = ref.read(languageProvider);
    final cachedMap = note.mindmapJsonByLang?[lang] ?? note.mindmapJson;

    if (cachedMap != null && cachedMap.isNotEmpty) {
      try {
        setState(() {
          _mindmapData = jsonDecode(cachedMap) as Map<String, dynamic>;
        });
        return;
      } catch (_) {
        // Fallback to regeneration if malformed
      }
    }

    // Otherwise generate using Gemini
    await _generateMindmap(note, lang);
  }

  Future<void> _generateMindmap(Note note, String lang) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final data = await gemini.generateMindMap(
        content: note.aiExplanation ?? note.content,
        language: lang,
      );

      if (data.isEmpty) {
        throw Exception('Failed to generate structural mind map JSON.');
      }

      final hive = ref.read(hiveServiceProvider);
      note.mindmapJson = jsonEncode(data);
      note.mindmapJsonByLang ??= {};
      note.mindmapJsonByLang![lang] = jsonEncode(data);

      await hive.upsertNote(note);
      await hive.addSyncTask(SyncTask.create(
        action: 'upsert',
        entityType: 'note',
        entityId: note.id,
        payload: note.toJson(),
      ));

      ref.read(hiveTickProvider.notifier).state++;
      unawaited(ref.read(syncServiceProvider).syncAll());

      setState(() {
        _mindmapData = data;
        _isGenerating = false;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final hive = ref.watch(hiveServiceProvider);
    final note = hive.getNote(widget.noteId);

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
                  Expanded(
                    child: Text(
                      note?.title ?? 'Mind Map',
                      style: AppTextStyles.h1.copyWith(fontSize: 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_mindmapData != null)
                    ScaleOnPress(
                      onTap: () {
                        if (note != null) _generateMindmap(note, lang);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Text(
                          'Regen',
                          style: AppTextStyles.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Canvas Area
            Expanded(
              child: _buildCanvasContent(note, lang),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasContent(Note? note, String lang) {
    if (_isGenerating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                lang == 'am' ? 'የሃሳብ ካርታ እየተፈጠረ ነው...' : 'Structuring mind map nodes...',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Gemini is breaking down key concepts into visual clusters.',
                style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to Load Mind Map', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.inkMid), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TemariButton(
                label: 'Retry Generation',
                onPressed: () {
                  if (note != null) _generateMindmap(note, lang);
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_mindmapData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Mind Map Layout coordinates calculation
    final centerTopic = _mindmapData!['center'] as String? ?? 'Core Concept';
    final branches = _mindmapData!['branches'] as List<dynamic>? ?? [];

    return InteractiveViewer(
      maxScale: 3.5,
      minScale: 0.3,
      boundaryMargin: const EdgeInsets.all(800),
      child: Center(
        child: SizedBox(
          width: 1000,
          height: 1000,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Custom paint to draw curved connect lines in background
              Positioned.fill(
                child: CustomPaint(
                  painter: MindmapLinesPainter(branchesCount: branches.length),
                ),
              ),

              // 1. Core Center Node
              Positioned(
                left: 500 - 90,
                top: 500 - 32,
                child: Container(
                  width: 180,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    centerTopic,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 2. Branch & Children Nodes
              ...List.generate(branches.length, (i) {
                final branchMap = branches[i] as Map<String, dynamic>;
                final label = branchMap['label'] as String? ?? 'Branch';
                final children = branchMap['children'] as List<dynamic>? ?? [];

                // Determine angle vector based on branch index (top-left, top-right, bottom-left, bottom-right)
                double angle;
                if (i == 0) {
                  angle = -3 * math.pi / 4; // Top Left
                } else if (i == 1) {
                  angle = -math.pi / 4; // Top Right
                } else if (i == 2) {
                  angle = 3 * math.pi / 4; // Bottom Left
                } else {
                  angle = math.pi / 4; // Bottom Right
                }

                final branchDistance = 200.0;
                final branchX = 500.0 + branchDistance * math.cos(angle);
                final branchY = 500.0 + branchDistance * math.sin(angle);

                final branchColor = AppColors.subjectColors[i % AppColors.subjectColors.length];

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The Branch Concept Node
                    Positioned(
                      left: branchX - 70,
                      top: branchY - 24,
                      child: Container(
                        width: 140,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: branchColor, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // Render Sub-concept Children Bubbles
                    ...List.generate(children.length, (j) {
                      final childText = children[j] as String? ?? 'Item';

                      // Children spread out radially around the branch node
                      final childAngle = angle + (j - (children.length - 1) / 2) * (math.pi / 6);
                      final childDistance = 110.0;
                      final childX = branchX + childDistance * math.cos(childAngle);
                      final childY = branchY + childDistance * math.sin(childAngle);

                      return Positioned(
                        left: childX - 55,
                        top: childY - 18,
                        child: Container(
                          width: 110,
                          height: 36,
                          decoration: BoxDecoration(
                            color: branchColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: branchColor.withValues(alpha: 0.3), width: 1),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            childText,
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.inkMid,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class MindmapLinesPainter extends CustomPainter {
  MindmapLinesPainter({required this.branchesCount});
  final int branchesCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < branchesCount; i++) {
      double angle;
      if (i == 0) {
        angle = -3 * math.pi / 4; // Top Left
      } else if (i == 1) {
        angle = -math.pi / 4; // Top Right
      } else if (i == 2) {
        angle = 3 * math.pi / 4; // Bottom Left
      } else {
        angle = math.pi / 4; // Bottom Right
      }

      final branchDistance = 200.0;
      final branchX = center.dx + branchDistance * math.cos(angle);
      final branchY = center.dy + branchDistance * math.sin(angle);
      final strokeColor = AppColors.subjectColors[i % AppColors.subjectColors.length];

      // Draw bezier line between core topic and branch node
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + (branchX - center.dx) * 0.4,
          center.dy,
          center.dx + (branchX - center.dx) * 0.6,
          branchY,
          branchX,
          branchY,
        );

      final paintLine = Paint()
        ..color = strokeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawPath(path, paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant MindmapLinesPainter oldDelegate) =>
      oldDelegate.branchesCount != branchesCount;
}
