import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfController _pdfController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    try {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.filePath),
      );
    } catch (_) {
      _hasError = true;
    }
  }

  @override
  void dispose() {
    if (!_hasError) {
      _pdfController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _hasError
          ? const Center(
              child: Text(
                'Failed to load PDF document.',
                style: TextStyle(color: AppColors.error),
              ),
            )
          : PdfView(
              controller: _pdfController,
              scrollDirection: Axis.vertical,
              builders: PdfViewBuilders<DefaultBuilderOptions>(
                options: const DefaultBuilderOptions(),
                documentLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                pageLoaderBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                errorBuilder: (_, err) => Center(
                  child: Text(
                    'Error loading page: $err',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
    );
  }
}
