import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/exam_session.dart';
import '../../shared/models/flashcard.dart';
import '../../shared/models/note.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/sync_task.dart';
import '../providers/bootstrap_providers.dart';
import '../providers/core_providers.dart';
import 'file_service.dart';
import 'hive_service.dart';

enum SyncStatus { synced, syncing, offlinePending, error }

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

class SyncService {
  SyncService(this.ref) {
    _init();
  }

  final Ref ref;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  HiveService get _hive => ref.read(hiveServiceProvider);
  SupabaseClient? get _client => ref.read(supabaseClientProvider);
  FileService get _fileService => ref.read(fileServiceProvider);

  void _init() {
    _connectivitySub = ref.read(connectivityServiceProvider).onConnectivityChanged.listen((results) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        syncAll();
      } else {
        _updateStatus();
      }
    });
    // Trigger initial sync check
    Future.microtask(() => syncAll());
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  void _updateStatus() {
    final statusNotifier = ref.read(syncStatusProvider.notifier);
    if (_isSyncing) {
      statusNotifier.state = SyncStatus.syncing;
    } else if (_hive.syncTasks.isNotEmpty) {
      statusNotifier.state = SyncStatus.offlinePending;
    } else {
      statusNotifier.state = SyncStatus.synced;
    }
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    final c = _client;
    if (c == null || c.auth.currentUser == null) {
      _updateStatus();
      return;
    }

    _isSyncing = true;
    _updateStatus();

    try {
      // 1. Process local mutations outbox (upload queue)
      await _processQueue();

      // 2. Pull remote changes down (two-way sync)
      await _pullRemoteChanges();
    } catch (e) {
      debugPrint('Sync failed: $e');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
    } finally {
      _isSyncing = false;
      _updateStatus();
    }
  }

  Future<void> _processQueue() async {
    final client = _client;
    if (client == null) return;

    final tasks = _hive.syncTasks;
    for (final task in tasks) {
      final uid = client.auth.currentUser?.id;
      if (uid == null) break;

      try {
        final table = _tableNameFor(task.entityType);

        if (task.action == 'delete') {
          await client.from(table).delete().eq('id', task.entityId);
        } else if (task.action == 'upsert') {
          var payload = Map<String, dynamic>.from(task.payload ?? {});

          // Handle offline-captured files before pushing DB row
          if (task.entityType == 'note') {
            final localPath = payload['local_file_path'] as String?;
            final fileUrl = payload['file_url'] as String?;
            if (localPath != null && fileUrl == null) {
              final file = File(localPath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final ext = p.extension(localPath);
                final remotePath = '$uid/notes/${task.entityId}$ext';
                final uploadedUrl = await _fileService.uploadIfSignedIn(
                  userId: uid,
                  bytes: bytes,
                  bucketPath: remotePath,
                );
                if (uploadedUrl != null) {
                  payload['file_url'] = uploadedUrl;
                  // Update Hive locally so it knows about the URL
                  final note = _hive.getNote(task.entityId);
                  if (note != null) {
                    note.fileUrl = uploadedUrl;
                    await _hive.upsertNote(note, touchUpdatedAt: false);
                  }
                }
              }
            }
          }

          // Prepare payload for Supabase insertion by sanitizing keys
          final sanitizedPayload = _sanitizePayload(task.entityType, payload);
          sanitizedPayload['user_id'] = uid;

          await client.from(table).upsert(sanitizedPayload);
        }

        // Task processed successfully, remove from queue
        await _hive.deleteSyncTask(task.id);
      } catch (e) {
        debugPrint('Failed to process task ${task.id}: $e');
        // If it's a network/connection failure, stop processing
        if (e is SocketException || e is TimeoutException) {
          rethrow;
        }
        // For standard errors (e.g. key constraint, permission), skip to avoid blocking the queue
        await _hive.deleteSyncTask(task.id);
      }
    }
  }

  Future<void> _pullRemoteChanges() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return;

    final lastSyncStr = _hive.settingsRaw['last_sync_at'] as String?;
    final lastSync = lastSyncStr != null ? DateTime.parse(lastSyncStr) : DateTime.fromMillisecondsSinceEpoch(0);

    final nowStr = DateTime.now().toUtc().toIso8601String();

    // Pull Subjects
    final remoteSubjects = await client
        .from('subjects')
        .select()
        .eq('user_id', uid)
        .gt('updated_at', lastSync.toIso8601String());
    for (final row in remoteSubjects as List<dynamic>) {
      final remote = Subject.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getSubject(remote.id);
      if (local == null) {
        await _hive.upsertSubject(remote);
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertSubject(remote);
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        // Local is newer, queue a push task to sync back
        await _hive.addSyncTask(SyncTask.create(
          action: 'upsert',
          entityType: 'subject',
          entityId: local.id,
          payload: local.toJson(),
        ));
      }
    }

    // Pull Notes
    final remoteNotes = await client
        .from('notes')
        .select()
        .eq('user_id', uid)
        .gt('updated_at', lastSync.toIso8601String());
    for (final row in remoteNotes as List<dynamic>) {
      final remote = Note.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getNote(remote.id);
      if (local == null) {
        await _hive.upsertNote(remote, touchUpdatedAt: false);
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertNote(remote, touchUpdatedAt: false);
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        await _hive.addSyncTask(SyncTask.create(
          action: 'upsert',
          entityType: 'note',
          entityId: local.id,
          payload: local.toJson(),
        ));
      }
    }

    // Pull Flashcards
    final remoteCards = await client
        .from('flashcards')
        .select()
        .eq('user_id', uid)
        .gt('updated_at', lastSync.toIso8601String());
    for (final row in remoteCards as List<dynamic>) {
      final remote = Flashcard.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getFlashcard(remote.id);
      if (local == null) {
        await _hive.upsertFlashcard(remote);
      } else if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertFlashcard(remote);
      } else if (local.updatedAt.isAfter(remote.updatedAt)) {
        await _hive.addSyncTask(SyncTask.create(
          action: 'upsert',
          entityType: 'flashcard',
          entityId: local.id,
          payload: local.toJson(),
        ));
      }
    }

    // Pull Exam Sessions
    final remoteSessions = await client
        .from('exam_sessions')
        .select()
        .eq('user_id', uid)
        .gt('updated_at', lastSync.toIso8601String());
    for (final row in remoteSessions as List<dynamic>) {
      final remote = ExamSession.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.sessions.firstWhere((e) => e.id == remote.id, orElse: () => remote);
      // Since ExamSession might not have updatedAt compare, LWW is simple
      if (local == remote) {
        await _hive.upsertSession(remote);
      }
    }

    // Update last sync time
    await _hive.patchSettings({
      'last_sync_at': nowStr,
    });
    ref.read(hiveTickProvider.notifier).state++;
  }

  String _tableNameFor(String entityType) {
    switch (entityType) {
      case 'subject':
        return 'subjects';
      case 'note':
        return 'notes';
      case 'flashcard':
        return 'flashcards';
      case 'exam_session':
        return 'exam_sessions';
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  Map<String, dynamic> _sanitizePayload(String entityType, Map<String, dynamic> raw) {
    final Map<String, dynamic> clean = {};
    switch (entityType) {
      case 'subject':
        final keys = ['id', 'user_id', 'name', 'color', 'icon', 'created_at', 'updated_at'];
        for (final k in keys) {
          if (raw.containsKey(k)) clean[k] = raw[k];
        }
        break;
      case 'note':
        final keys = [
          'id',
          'user_id',
          'subject_id',
          'title',
          'content',
          'type',
          'file_url',
          'ai_summary',
          'ai_explanation',
          'language',
          'created_at',
          'updated_at'
        ];
        for (final k in keys) {
          if (raw.containsKey(k)) clean[k] = raw[k];
        }
        break;
      case 'flashcard':
        final keys = [
          'id',
          'user_id',
          'note_id',
          'subject_id',
          'question',
          'answer',
          'difficulty',
          'next_review',
          'review_count',
          'created_at',
          'updated_at'
        ];
        for (final k in keys) {
          if (raw.containsKey(k)) clean[k] = raw[k];
        }
        break;
      case 'exam_session':
        final keys = ['id', 'user_id', 'subject_id', 'exam_date', 'total_cards', 'correct_count', 'created_at', 'updated_at'];
        for (final k in keys) {
          if (raw.containsKey(k)) clean[k] = raw[k];
        }
        if (!clean.containsKey('updated_at') && raw.containsKey('created_at')) {
          clean['updated_at'] = raw['created_at'];
        }
        break;
    }
    return clean;
  }
}
