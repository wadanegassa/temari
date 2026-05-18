import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local file paths + optional Supabase Storage uploads.
class FileService {
  FileService(this._client);

  final SupabaseClient? _client;

  Future<Directory> get _root async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'temari_files'));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<String> saveLocalCopy({
    required String userId,
    required List<int> bytes,
    required String category,
    required String filename,
  }) async {
    final root = await _root;
    final folder = Directory(p.join(root.path, userId, category));
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(p.join(folder.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Returns public/signed URL when Supabase is configured, else null.
  Future<String?> uploadIfSignedIn({
    required String userId,
    required List<int> bytes,
    required String bucketPath,
    String bucket = 'temari-files',
  }) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return null;
    await client.storage.from(bucket).uploadBinary(
          bucketPath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from(bucket).getPublicUrl(bucketPath);
  }
}
