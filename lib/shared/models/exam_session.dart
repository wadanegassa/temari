import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ExamSession {
  ExamSession({
    required this.id,
    required this.userId,
    required this.subjectId,
    this.examDate,
    this.totalCards = 0,
    this.correctCount = 0,
    required this.createdAt,
    this.weakTopicHints = const [],
  });

  final String id;
  final String userId;
  final String subjectId;
  final DateTime? examDate;
  int totalCards;
  int correctCount;
  final DateTime createdAt;
  List<String> weakTopicHints;

  factory ExamSession.create({
    required String userId,
    required String subjectId,
    int totalCards = 0,
    int correctCount = 0,
    List<String> weakTopicHints = const [],
  }) {
    return ExamSession(
      id: _uuid.v4(),
      userId: userId,
      subjectId: subjectId,
      examDate: DateTime.now().toUtc(),
      totalCards: totalCards,
      correctCount: correctCount,
      createdAt: DateTime.now().toUtc(),
      weakTopicHints: weakTopicHints,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'subject_id': subjectId,
        'exam_date': examDate?.toIso8601String(),
        'total_cards': totalCards,
        'correct_count': correctCount,
        'created_at': createdAt.toIso8601String(),
        'weak_topic_hints': weakTopicHints,
      };

  factory ExamSession.fromJson(Map<String, dynamic> j) {
    return ExamSession(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['userId']) as String,
      subjectId: (j['subject_id'] ?? j['subjectId']) as String,
      examDate: j['exam_date'] != null
          ? DateTime.parse(j['exam_date'] as String)
          : null,
      totalCards: (j['total_cards'] ?? 0) as int,
      correctCount: (j['correct_count'] ?? 0) as int,
      createdAt: DateTime.parse(j['created_at'] as String),
      weakTopicHints: (j['weak_topic_hints'] as List?)?.cast<String>() ?? [],
    );
  }

  double get scoreFraction =>
      totalCards == 0 ? 0 : correctCount / totalCards;
}

String examSessionToJsonString(ExamSession s) => jsonEncode(s.toJson());
