import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/subject.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

final subjectsProvider = Provider<List<Subject>>((ref) {
  ref.watch(authControllerProvider);
  ref.watch(settingsControllerProvider);
  ref.watch(hiveTickProvider);
  return ref.watch(hiveServiceProvider).subjects;
});

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository(ref);
});

class SubjectRepository {
  SubjectRepository(this.ref);

  final Ref ref;

  HiveService get _hive => ref.read(hiveServiceProvider);
  SupabaseClient? get _client => ref.read(supabaseClientProvider);
  SupabaseService get _sb => ref.read(supabaseServiceProvider);

  Future<void> save(Subject s) async {
    await _hive.upsertSubject(s);
    await _sb.pushUpsertSubject(s);
    ref.read(hiveTickProvider.notifier).state++;
  }

  Future<void> delete(String id) async {
    await _hive.deleteSubject(id);
    ref.read(hiveTickProvider.notifier).state++;
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c != null && uid != null) {
      await c.from('subjects').delete().eq('id', id);
    }
  }
}
