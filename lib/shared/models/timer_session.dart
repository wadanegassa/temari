import 'dart:convert';
import 'package:uuid/uuid.dart';

class TimerSession {
  TimerSession({
    required this.id,
    required this.userId,
    this.subjectId,
    required this.durationMinutes,
    required this.completed,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? subjectId;
  final int durationMinutes;
  final bool completed;
  final DateTime createdAt;

  factory TimerSession.create({
    required String userId,
    String? subjectId,
    required int durationMinutes,
    required bool completed,
  }) {
    return TimerSession(
      id: const Uuid().v4(),
      userId: userId,
      subjectId: subjectId,
      durationMinutes: durationMinutes,
      completed: completed,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'subject_id': subjectId,
        'duration_minutes': durationMinutes,
        'completed': completed,
        'created_at': createdAt.toIso8601String(),
      };

  factory TimerSession.fromJson(Map<String, dynamic> j) {
    return TimerSession(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['userId']) as String,
      subjectId: (j['subject_id'] ?? j['subjectId']) as String?,
      durationMinutes: (j['duration_minutes'] ?? j['durationMinutes'] ?? 0) as int,
      completed: (j['completed'] ?? false) as bool,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  static TimerSession fromJsonString(String s) =>
      TimerSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
  String toJsonString() => jsonEncode(toJson());
}
