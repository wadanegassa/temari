import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../shared/models/timer_session.dart';

enum PomodoroMode { focus, shortBreak, longBreak }

class TimerState {
  TimerState({
    required this.mode,
    required this.durationSeconds,
    required this.secondsRemaining,
    required this.isRunning,
    this.selectedSubjectId,
    required this.completedSessionsToday,
  });

  final PomodoroMode mode;
  final int durationSeconds;
  final int secondsRemaining;
  final bool isRunning;
  final String? selectedSubjectId;
  final int completedSessionsToday;

  TimerState copyWith({
    PomodoroMode? mode,
    int? durationSeconds,
    int? secondsRemaining,
    bool? isRunning,
    String? Function()? selectedSubjectId,
    int? completedSessionsToday,
  }) {
    return TimerState(
      mode: mode ?? this.mode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isRunning: isRunning ?? this.isRunning,
      selectedSubjectId: selectedSubjectId != null ? selectedSubjectId() : this.selectedSubjectId,
      completedSessionsToday: completedSessionsToday ?? this.completedSessionsToday,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  TimerNotifier(this.ref)
      : super(TimerState(
          mode: PomodoroMode.focus,
          durationSeconds: 25 * 60,
          secondsRemaining: 25 * 60,
          isRunning: false,
          completedSessionsToday: 0,
        )) {
    _loadCompletedSessionsCount();
  }

  final Ref ref;
  Timer? _ticker;

  void _loadCompletedSessionsCount() {
    final sessions = ref.read(hiveServiceProvider).timerSessions;
    final today = DateTime.now();
    final count = sessions.where((s) {
      final diff = today.difference(s.createdAt);
      return diff.inDays == 0 && s.completed;
    }).length;
    state = state.copyWith(completedSessionsToday: count);
  }

  void setSubject(String? subjectId) {
    state = state.copyWith(selectedSubjectId: () => subjectId);
  }

  void selectMode(PomodoroMode mode) {
    _ticker?.cancel();
    int mins = 25;
    if (mode == PomodoroMode.shortBreak) mins = 5;
    if (mode == PomodoroMode.longBreak) mins = 15;

    state = state.copyWith(
      mode: mode,
      durationSeconds: mins * 60,
      secondsRemaining: mins * 60,
      isRunning: false,
    );
  }

  void toggleTimer() {
    if (state.isRunning) {
      _ticker?.cancel();
      state = state.copyWith(isRunning: false);
    } else {
      state = state.copyWith(isRunning: true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.secondsRemaining <= 1) {
          _ticker?.cancel();
          _completeSession();
        } else {
          state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
        }
      });
    }
  }

  Future<void> _completeSession() async {
    final currentMode = state.mode;
    final isFocus = currentMode == PomodoroMode.focus;

    if (isFocus) {
      final hive = ref.read(hiveServiceProvider);
      final uid = hive.localUserId.isNotEmpty ? hive.localUserId : 'offline_user';
      final session = TimerSession.create(
        userId: uid,
        subjectId: state.selectedSubjectId,
        durationMinutes: state.durationSeconds ~/ 60,
        completed: true,
      );
      await hive.upsertTimerSession(session);
      
      // Attempt pushing to cloud if configured and online
      try {
        final client = ref.read(supabaseServiceProvider).client;
        if (client != null && client.auth.currentUser != null) {
          await client.from('timer_sessions').insert(session.toJson());
        }
      } catch (_) {
        // Safe failover to offline-first locally
      }
    }

    _loadCompletedSessionsCount();

    // Auto rotate modes
    if (isFocus) {
      final nextMode = (state.completedSessionsToday + 1) % 4 == 0
          ? PomodoroMode.longBreak
          : PomodoroMode.shortBreak;
      selectMode(nextMode);
    } else {
      selectMode(PomodoroMode.focus);
    }
  }

  void resetTimer() {
    _ticker?.cancel();
    state = state.copyWith(
      secondsRemaining: state.durationSeconds,
      isRunning: false,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(ref);
});
