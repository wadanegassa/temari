import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../shared/models/exam_session.dart';
import '../../shared/models/flashcard.dart';
import '../../shared/models/note.dart';
import '../../shared/models/subject.dart';
import '../../shared/models/timer_session.dart';

const kSettingsBox = 'settingsBox';
const kSubjectsBox = 'subjectsBox';
const kNotesBox = 'notesBox';
const kFlashcardsBox = 'flashcardsBox';
const kSessionsBox = 'sessionsBox'; // Exam sessions
const kTimerSessionsBox = 'timerSessionsBox'; // Pomodoro sessions

class HiveService {
  Box<Map>? _settings;
  Box<Map>? _subjects;
  Box<Map>? _notes;
  Box<Map>? _flashcards;
  Box<Map>? _sessions;
  Box<Map>? _timerSessions;

  Future<void> init() async {
    await Hive.initFlutter();
    _settings = await Hive.openBox<Map>(kSettingsBox);
    _subjects = await Hive.openBox<Map>(kSubjectsBox);
    _notes = await Hive.openBox<Map>(kNotesBox);
    _flashcards = await Hive.openBox<Map>(kFlashcardsBox);
    _sessions = await Hive.openBox<Map>(kSessionsBox);
    _timerSessions = await Hive.openBox<Map>(kTimerSessionsBox);
  }

  Map<String, dynamic> _castMap(dynamic v) =>
      Map<String, dynamic>.from(v as Map);

  // --- Settings ---
  Map<String, dynamic> get settingsRaw =>
      Map<String, dynamic>.from(_settings?.get('app', defaultValue: <String, dynamic>{}) ?? {});

  Future<void> patchSettings(Map<String, dynamic> patch) async {
    final m = settingsRaw;
    m.addAll(patch);
    await _settings?.put('app', m);
  }

  String get localUserId =>
      settingsRaw['local_user_id'] as String? ?? '';

  Future<void> ensureLocalUserId(String id) async {
    if ((settingsRaw['local_user_id'] as String?)?.isNotEmpty ?? false) {
      return;
    }
    await patchSettings({'local_user_id': id});
  }

  // --- Subjects ---
  List<Subject> get subjects {
    final box = _subjects;
    if (box == null) return [];
    return box.values
        .map((e) => Subject.fromJson(_castMap(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Subject? getSubject(String id) {
    final raw = _subjects?.get(id);
    if (raw == null) return null;
    return Subject.fromJson(_castMap(raw));
  }

  Future<void> upsertSubject(Subject s) async {
    await _subjects?.put(s.id, s.toJson());
  }

  Future<void> deleteSubject(String id) async {
    await _subjects?.delete(id);
    for (final n in notes.where((e) => e.subjectId == id).toList()) {
      await deleteNote(n.id);
    }
    for (final f in flashcards.where((e) => e.subjectId == id).toList()) {
      await deleteFlashcard(f.id);
    }
  }

  // --- Notes ---
  List<Note> get notes {
    final box = _notes;
    if (box == null) return [];
    return box.values
        .map((e) => Note.fromJson(_castMap(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<Note> notesForSubject(String subjectId) =>
      notes.where((n) => n.subjectId == subjectId).toList();

  Note? getNote(String id) {
    final raw = _notes?.get(id);
    if (raw == null) return null;
    return Note.fromJson(_castMap(raw));
  }

  Future<void> upsertNote(Note n, {bool touchUpdatedAt = true}) async {
    if (touchUpdatedAt) {
      n.updatedAt = DateTime.now().toUtc();
    }
    await _notes?.put(n.id, n.toJson());
  }

  Future<void> deleteNote(String id) async {
    await _notes?.delete(id);
    for (final f in flashcards.where((e) => e.noteId == id).toList()) {
      await deleteFlashcard(f.id);
    }
  }

  // --- Flashcards ---
  List<Flashcard> get flashcards {
    final box = _flashcards;
    if (box == null) return [];
    return box.values
        .map((e) => Flashcard.fromJson(_castMap(e)))
        .toList()
      ..sort((a, b) => a.nextReview.compareTo(b.nextReview));
  }

  List<Flashcard> flashcardsForSubject(String subjectId) =>
      flashcards.where((f) => f.subjectId == subjectId).toList();

  Flashcard? getFlashcard(String id) {
    final raw = _flashcards?.get(id);
    if (raw == null) return null;
    return Flashcard.fromJson(_castMap(raw));
  }

  Future<void> upsertFlashcard(Flashcard f) async {
    await _flashcards?.put(f.id, f.toJson());
  }

  Future<void> deleteFlashcard(String id) async {
    await _flashcards?.delete(id);
  }

  // --- Exam Sessions ---
  List<ExamSession> get sessions {
    final box = _sessions;
    if (box == null) return [];
    return box.values
        .map((e) => ExamSession.fromJson(_castMap(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertSession(ExamSession s) async {
    await _sessions?.put(s.id, s.toJson());
  }

  // --- Timer Sessions ---
  List<TimerSession> get timerSessions {
    final box = _timerSessions;
    if (box == null) return [];
    return box.values
        .map((e) => TimerSession.fromJson(_castMap(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> upsertTimerSession(TimerSession s) async {
    await _timerSessions?.put(s.id, s.toJson());
  }

  /// Full JSON export for settings screen.
  String exportAllJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'settings': settingsRaw,
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'flashcards': flashcards.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'timer_sessions': timerSessions.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> wipeLocalData() async {
    await _subjects?.clear();
    await _notes?.clear();
    await _flashcards?.clear();
    await _sessions?.clear();
    await _timerSessions?.clear();
    final uid = settingsRaw['local_user_id'];
    final lang = settingsRaw['language'] ?? 'en';
    final onboard = settingsRaw['onboarding_complete'] ?? false;
    await _settings?.clear();
    await patchSettings({
      ...{
        if (uid != null) 'local_user_id': uid,
      },
      'language': lang,
      'onboarding_complete': onboard,
    });
  }
}
