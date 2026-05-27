import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/services/hive_service.dart';
import '../../../shared/models/subject.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

import '../../../core/providers/core_providers.dart';
import '../../../shared/models/sync_task.dart';

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

  Future<void> save(Subject s) async {
    await _hive.upsertSubject(s);
    await _hive.addSyncTask(SyncTask.create(
      action: 'upsert',
      entityType: 'subject',
      entityId: s.id,
      payload: s.toJson(),
    ));
    ref.read(hiveTickProvider.notifier).state++;
    unawaited(ref.read(syncServiceProvider).syncAll());
  }

  Future<void> delete(String id) async {
    await _hive.deleteSubject(id);
    await _hive.addSyncTask(SyncTask.create(
      action: 'delete',
      entityType: 'subject',
      entityId: id,
    ));
    ref.read(hiveTickProvider.notifier).state++;
    unawaited(ref.read(syncServiceProvider).syncAll());
  }
}
