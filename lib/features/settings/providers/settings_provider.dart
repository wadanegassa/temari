import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/services/hive_service.dart';

final settingsControllerProvider =
    ChangeNotifierProvider<SettingsController>((ref) {
  final c = SettingsController(ref);
  ref.onDispose(c.dispose);
  return c;
});

class SettingsController extends ChangeNotifier {
  SettingsController(this.ref);

  final Ref ref;

  HiveService get _hive => ref.read(hiveServiceProvider);

  Map<String, dynamic> get _s => _hive.settingsRaw;

  String get language => _s['language'] as String? ?? 'en';

  bool get onboardingComplete => _s['onboarding_complete'] == true;

  bool get dailyReminder => _s['daily_reminder'] == true;

  String? get dailyReminderTime => _s['daily_reminder_time'] as String?;

  bool get autoFlashcards => _s['auto_flashcards'] != false;

  String? get displayName => _s['display_name'] as String?;

  bool get isPro => _s['is_pro'] == true;

  Future<void> setLanguage(String code) async {
    await _hive.patchSettings({'language': code});
    notifyListeners();
  }

  Future<void> setOnboardingComplete(bool v) async {
    await _hive.patchSettings({'onboarding_complete': v});
    notifyListeners();
  }

  Future<void> setDisplayName(String? name) async {
    await _hive.patchSettings({'display_name': name});
    notifyListeners();
  }

  Future<void> setDailyReminder(bool v, {String? time}) async {
    await _hive.patchSettings({
      'daily_reminder': v,
      if (time != null) 'daily_reminder_time': time,
    });
    notifyListeners();
  }

  Future<void> setAutoFlashcards(bool v) async {
    await _hive.patchSettings({'auto_flashcards': v});
    notifyListeners();
  }

  Future<void> setPro(bool v) async {
    await _hive.patchSettings({'is_pro': v});
    notifyListeners();
  }
}

final languageProvider = Provider<String>((ref) {
  return ref.watch(settingsControllerProvider).language;
});
