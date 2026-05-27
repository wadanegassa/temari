import 'dart:convert';
import 'package:uuid/uuid.dart';

class SyncTask {
  SyncTask({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.payload,
  });

  final String id;
  final String action; // 'upsert' | 'delete'
  final String entityType; // 'subject' | 'note' | 'flashcard' | 'exam_session'
  final String entityId;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  factory SyncTask.create({
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
  }) {
    return SyncTask(
      id: const Uuid().v4(),
      action: action,
      entityType: entityType,
      entityId: entityId,
      createdAt: DateTime.now().toUtc(),
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'created_at': createdAt.toIso8601String(),
        if (payload != null) 'payload': payload,
      };

  factory SyncTask.fromJson(Map<String, dynamic> j) {
    return SyncTask(
      id: j['id'] as String,
      action: j['action'] as String,
      entityType: (j['entity_type'] ?? j['entityType']) as String,
      entityId: (j['entity_id'] ?? j['entityId']) as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      payload: j['payload'] != null ? Map<String, dynamic>.from(j['payload'] as Map) : null,
    );
  }

  static SyncTask fromJsonString(String s) =>
      SyncTask.fromJson(jsonDecode(s) as Map<String, dynamic>);
  String toJsonString() => jsonEncode(toJson());
}
