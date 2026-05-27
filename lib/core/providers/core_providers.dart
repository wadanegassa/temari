import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap_providers.dart';
import '../services/connectivity_service.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';
import '../services/sync_service.dart';

import '../../features/settings/providers/settings_provider.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final model = ref.watch(settingsControllerProvider).aiModel;
  return GeminiService(model: model);
});

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final fileServiceProvider = Provider<FileService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return FileService(client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});
