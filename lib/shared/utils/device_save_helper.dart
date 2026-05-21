import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DeviceSaveHelper {
  static Future<void> saveTextFile({
    required BuildContext context,
    required String fileName,
    required String textContent,
  }) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsString(textContent);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to device successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> saveBinaryFile({
    required BuildContext context,
    required String fileName,
    required List<int> bytes,
    String? extension,
  }) async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: extension != null ? [extension] : null,
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to device successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
