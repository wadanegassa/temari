import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Flashcard {
  Flashcard({
    required this.id,
    required this.userId,
    required this.noteId,
    required this.subjectId,
    required this.question,
    required this.answer,
    this.difficulty = 0,
    required this.nextReview,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String noteId;
  final String subjectId;
  final String question;
  final String answer;
  int difficulty;
  DateTime nextReview;
  int reviewCount;
  final DateTime createdAt;
  DateTime updatedAt;

  factory Flashcard.create({
    required String userId,
    required String noteId,
    required String subjectId,
    required String question,
    required String answer,
  }) {
    final now = DateTime.now().toUtc();
    return Flashcard(
      id: _uuid.v4(),
      userId: userId,
      noteId: noteId,
      subjectId: subjectId,
      question: question,
      answer: answer,
      nextReview: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'note_id': noteId,
        'subject_id': subjectId,
        'question': question,
        'answer': answer,
        'difficulty': difficulty,
        'next_review': nextReview.toIso8601String(),
        'review_count': reviewCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) {
    return Flashcard(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['userId']) as String,
      noteId: (j['note_id'] ?? j['noteId']) as String,
      subjectId: (j['subject_id'] ?? j['subjectId']) as String,
      question: j['question'] as String,
      answer: j['answer'] as String,
      difficulty: (j['difficulty'] ?? 0) as int,
      nextReview: DateTime.parse(j['next_review'] as String),
      reviewCount: (j['review_count'] ?? 0) as int,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
          DateTime.parse(j['created_at'] as String),
    );
  }
}

/// Spaced repetition scheduling.
void applyReviewResult(Flashcard card, int result) {
  final now = DateTime.now().toUtc();
  switch (result) {
    case 2:
      card.nextReview = now.add(const Duration(days: 3));
      card.difficulty = (card.difficulty - 1).clamp(0, 3);
      break;
    case 1:
      card.nextReview = now.add(const Duration(days: 1));
      break;
    default:
      card.nextReview = now.add(const Duration(hours: 2));
      card.difficulty = (card.difficulty + 1).clamp(0, 3);
      break;
  }
  card.reviewCount += 1;
  card.updatedAt = now;
}

String flashcardToJsonString(Flashcard c) => jsonEncode(c.toJson());
