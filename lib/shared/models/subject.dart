import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Subject {
  Subject({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.lastStudiedAt,
    this.remoteSyncedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final String iconName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastStudiedAt;
  final DateTime? remoteSyncedAt;

  factory Subject.create({
    required String userId,
    required String name,
    required String colorHex,
    String iconName = 'book',
  }) {
    final now = DateTime.now().toUtc();
    return Subject(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      colorHex: colorHex,
      iconName: iconName,
      createdAt: now,
      updatedAt: now,
    );
  }

  Subject copyWith({
    String? name,
    String? colorHex,
    String? iconName,
    DateTime? lastStudiedAt,
    DateTime? updatedAt,
    DateTime? remoteSyncedAt,
  }) {
    return Subject(
      id: id,
      userId: userId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      remoteSyncedAt: remoteSyncedAt ?? this.remoteSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': colorHex,
        'icon': iconName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_studied_at': lastStudiedAt?.toIso8601String(),
        'remote_synced_at': remoteSyncedAt?.toIso8601String(),
      };

  factory Subject.fromJson(Map<String, dynamic> j) {
    return Subject(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['userId']) as String,
      name: j['name'] as String,
      colorHex: (j['color'] ?? j['colorHex']) as String,
      iconName: (j['icon'] ?? j['iconName'] ?? 'book') as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
          DateTime.parse(j['created_at'] as String),
      lastStudiedAt: j['last_studied_at'] != null
          ? DateTime.parse(j['last_studied_at'] as String)
          : null,
      remoteSyncedAt: j['remote_synced_at'] != null
          ? DateTime.parse(j['remote_synced_at'] as String)
          : null,
    );
  }

  static Subject fromJsonString(String s) =>
      Subject.fromJson(jsonDecode(s) as Map<String, dynamic>);
  String toJsonString() => jsonEncode(toJson());
}
