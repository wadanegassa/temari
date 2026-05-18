import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/flashcard.dart';
import '../../shared/models/note.dart';
import '../../shared/models/subject.dart';
import 'hive_service.dart';
import '../config/app_env.dart';

class SupabaseBootstrap {
  static bool get configured =>
      AppEnv.supabaseUrl.isNotEmpty && AppEnv.supabaseAnonKey.isNotEmpty;

  static Future<SupabaseClient?> init() async {
    if (!configured) return null;
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    return Supabase.instance.client;
  }
}

/// Auth + optional cloud sync. Safe no-op when Supabase is not configured.
class SupabaseService {
  SupabaseService(this._client, this._hive);

  final SupabaseClient? _client;
  final HiveService _hive;

  SupabaseClient? get client => _client;

  User? get currentUser => _client?.auth.currentUser;

  Stream<Session?> get authStateChanges =>
      _client?.auth.onAuthStateChange.map((e) => e.session) ??
      const Stream<Session?>.empty();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final c = _client;
    if (c == null) throw StateError('Supabase not configured');
    final res = await c.auth.signUp(email: email, password: password);
    final uid = res.user?.id;
    if (uid != null) {
      await c.from('profiles').upsert({
        'id': uid,
        'display_name': displayName ?? email.split('@').first,
        'preferred_language': _hive.settingsRaw['language'] ?? 'en',
      });
    }
    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final c = _client;
    if (c == null) throw StateError('Supabase not configured');
    return c.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  /// Pull cloud rows into Hive (last-write-wins by updated_at).
  Future<void> pullRemoteIntoHive() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;

    final subjects = await c.from('subjects').select().eq('user_id', uid);
    for (final row in subjects as List<dynamic>) {
      final remote = Subject.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getSubject(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertSubject(remote);
      }
    }

    final notes = await c.from('notes').select().eq('user_id', uid);
    for (final row in notes as List<dynamic>) {
      final remote = Note.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getNote(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertNote(remote);
      }
    }

    final cards = await c.from('flashcards').select().eq('user_id', uid);
    for (final row in cards as List<dynamic>) {
      final remote =
          Flashcard.fromJson(Map<String, dynamic>.from(row as Map));
      final local = _hive.getFlashcard(remote.id);
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await _hive.upsertFlashcard(remote);
      }
    }

    await _hive.patchSettings({
      'last_sync_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> pushUpsertSubject(Subject s) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    await c.from('subjects').upsert({
      'id': s.id,
      'user_id': uid,
      'name': s.name,
      'color': s.colorHex,
      'icon': s.iconName,
      'created_at': s.createdAt.toIso8601String(),
    });
  }

  Future<void> pushUpsertNote(Note n) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    await c.from('notes').upsert({
      'id': n.id,
      'user_id': uid,
      'subject_id': n.subjectId,
      'title': n.title,
      'content': n.content,
      'type': n.type,
      'file_url': n.fileUrl,
      'ai_summary': n.aiSummary,
      'ai_explanation': n.aiExplanation,
      'language': n.language,
      'created_at': n.createdAt.toIso8601String(),
    });
  }

  Future<void> pushUpsertFlashcard(Flashcard f) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return;
    await c.from('flashcards').upsert({
      'id': f.id,
      'user_id': uid,
      'note_id': f.noteId,
      'subject_id': f.subjectId,
      'question': f.question,
      'answer': f.answer,
      'difficulty': f.difficulty,
      'next_review': f.nextReview.toIso8601String(),
      'review_count': f.reviewCount,
      'created_at': f.createdAt.toIso8601String(),
    });
  }
}
