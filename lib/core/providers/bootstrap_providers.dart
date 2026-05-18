import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/hive_service.dart';
import '../services/supabase_service.dart';

/// Bump after local Hive mutations so UI rebuilds.
final hiveTickProvider = StateProvider<int>((ref) => 0);

/// Overridden in `main.dart` after Hive is opened.
final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('Override hiveServiceProvider in ProviderScope');
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final hive = ref.watch(hiveServiceProvider);
  return SupabaseService(client, hive);
});
