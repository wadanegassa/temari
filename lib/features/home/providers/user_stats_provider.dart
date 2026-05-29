import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/bootstrap_providers.dart';

final userStatsProvider = StateNotifierProvider<UserStatsNotifier, UserStats>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return UserStatsNotifier(hive);
});

class UserStats {
  final int xp;
  final int streak;
  final DateTime? lastStudyDate;

  UserStats({
    required this.xp,
    required this.streak,
    this.lastStudyDate,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      xp: json['xp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      lastStudyDate: json['last_study_date'] != null
          ? DateTime.tryParse(json['last_study_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'streak': streak,
      'last_study_date': lastStudyDate?.toIso8601String(),
    };
  }

  UserStats copyWith({int? xp, int? streak, DateTime? lastStudyDate}) {
    return UserStats(
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}

class UserStatsNotifier extends StateNotifier<UserStats> {
  final dynamic hive;

  UserStatsNotifier(this.hive) : super(UserStats.fromJson(hive.settingsRaw)) {
    _checkStreak();
  }

  void _checkStreak() {
    if (state.lastStudyDate == null) return;
    
    final now = DateTime.now();
    final last = state.lastStudyDate!;
    final diff = now.difference(last).inDays;
    
    // If it's been more than 1 day (technically midnight crossing, but 24h is simpler), reset streak
    if (diff > 1 && now.day != last.day + 1) {
      state = state.copyWith(streak: 0);
      _save();
    }
  }

  void addXp(int amount) {
    final now = DateTime.now();
    int newStreak = state.streak;
    
    // Increment streak if it's a new day
    if (state.lastStudyDate == null || state.lastStudyDate!.day != now.day) {
      newStreak++;
    }

    state = state.copyWith(
      xp: state.xp + amount,
      streak: newStreak,
      lastStudyDate: now,
    );
    _save();
  }

  void _save() {
    hive.patchSettings(state.toJson());
  }
}
