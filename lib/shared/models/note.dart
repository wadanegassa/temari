import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// voice | text | photo | file (PDF)
typedef NoteType = String;

const noteTypeVoice = 'voice';
const noteTypeText = 'text';
const noteTypePhoto = 'photo';
const noteTypeFile = 'file';

const aiStatusReady = 'ready';
const aiStatusPending = 'pending_ai';
const aiStatusError = 'error';

class Note {
  Note({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.title,
    required this.content,
    required this.type,
    this.fileUrl,
    this.localFilePath,
    this.aiSummary,
    this.aiExplanation,
    this.aiExplanationByLang,
    this.predictedQuestions,
    this.predictedQuestionsByLang,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.aiStatus = aiStatusReady,
  });

  final String id;
  final String userId;
  final String subjectId;
  String title;
  String content;
  final String type;
  String? fileUrl;
  String? localFilePath;
  String? aiSummary;
  String? aiExplanation;
  /// Cached explanations when student toggles EN/AM/OM.
  Map<String, String>? aiExplanationByLang;
  List<String>? predictedQuestions;
  Map<String, List<String>>? predictedQuestionsByLang;
  String language;
  final DateTime createdAt;
  DateTime updatedAt;
  String aiStatus;

  factory Note.create({
    required String userId,
    required String subjectId,
    required String type,
    String title = '',
    String content = '',
    String language = 'en',
    String? localFilePath,
  }) {
    final now = DateTime.now().toUtc();
    return Note(
      id: _uuid.v4(),
      userId: userId,
      subjectId: subjectId,
      title: title,
      content: content,
      type: type,
      localFilePath: localFilePath,
      language: language,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'subject_id': subjectId,
        'title': title,
        'content': content,
        'type': type,
        'file_url': fileUrl,
        'local_file_path': localFilePath,
        'ai_summary': aiSummary,
        'ai_explanation': aiExplanation,
        'ai_explanation_by_lang': aiExplanationByLang,
        'predicted_questions': predictedQuestions,
        'predicted_questions_by_lang': predictedQuestionsByLang,
        'language': language,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'ai_status': aiStatus,
      };

  factory Note.fromJson(Map<String, dynamic> j) {
    Map<String, String>? byLang;
    final raw = j['ai_explanation_by_lang'];
    if (raw is Map) {
      byLang = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    Map<String, List<String>>? predByLang;
    final pr = j['predicted_questions_by_lang'];
    if (pr is Map) {
      predByLang = pr.map(
        (k, v) => MapEntry(
          k.toString(),
          (v as List).map((e) => e.toString()).toList(),
        ),
      );
    }
    return Note(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['userId']) as String,
      subjectId: (j['subject_id'] ?? j['subjectId']) as String,
      title: (j['title'] ?? '') as String,
      content: (j['content'] ?? '') as String,
      type: j['type'] as String,
      fileUrl: j['file_url'] as String?,
      localFilePath: j['local_file_path'] as String?,
      aiSummary: j['ai_summary'] as String?,
      aiExplanation: j['ai_explanation'] as String?,
      aiExplanationByLang: byLang,
      predictedQuestions: (j['predicted_questions'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      predictedQuestionsByLang: predByLang,
      language: (j['language'] ?? 'en') as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
          DateTime.parse(j['created_at'] as String),
      aiStatus: (j['ai_status'] ?? aiStatusReady) as String,
    );
  }
}
