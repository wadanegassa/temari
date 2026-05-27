import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/bootstrap_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/supabase_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.ref);

  final Ref ref;

  bool ready = false;
  bool anonymous = true;
  Session? session;
  StreamSubscription? _authSub;

  HiveService get _hive => ref.read(hiveServiceProvider);
  SupabaseService get _sb => ref.read(supabaseServiceProvider);

  String get effectiveUserId =>
      session?.user.id ?? _hive.settingsRaw['local_user_id'] as String? ?? '';

  Future<void> bootstrap() async {
    var uid = _hive.settingsRaw['local_user_id'] as String?;
    if (uid == null || uid.isEmpty) {
      uid = const Uuid().v4();
      await _hive.patchSettings({'local_user_id': uid});
    }
    session = _sb.client?.auth.currentSession;
    anonymous = session == null;
    await _authSub?.cancel();
    _authSub = _sb.client?.auth.onAuthStateChange.listen((event) {
      session = event.session;
      anonymous = session == null;
      notifyListeners();
    });
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  Future<Session?> signIn(String email, String password) async {
    final guestId = _hive.settingsRaw['local_user_id'] as String? ?? '';
    final response = await _sb.signIn(email: email, password: password);
    session = response.session;
    anonymous = session == null;
    await _hive.patchSettings({'anonymous': anonymous});
    if (session != null) {
      final newUserId = session!.user.id;
      if (guestId.isNotEmpty && guestId != newUserId) {
        await _hive.migrateGuestData(guestId, newUserId);
      }
      unawaited(ref.read(syncServiceProvider).syncAll());
    }
    notifyListeners();
    return session;
  }

  Future<Session?> signUp(String email, String password, String? name) async {
    final guestId = _hive.settingsRaw['local_user_id'] as String? ?? '';
    final response = await _sb.signUp(email: email, password: password, displayName: name);
    session = response.session;
    anonymous = session == null;
    await _hive.patchSettings({'anonymous': anonymous});
    if (session != null) {
      final newUserId = session!.user.id;
      if (guestId.isNotEmpty && guestId != newUserId) {
        await _hive.migrateGuestData(guestId, newUserId);
      }
      unawaited(ref.read(syncServiceProvider).syncAll());
    }
    notifyListeners();
    return session;
  }

  Future<void> signOut() async {
    await _sb.signOut();
    session = null;
    anonymous = true;
    await _hive.patchSettings({'anonymous': true});
    notifyListeners();
  }

  Future<void> continueWithoutAccount() async {
    anonymous = true;
    session = null;
    await _hive.patchSettings({'anonymous': true});
    notifyListeners();
  }
}

final authControllerProvider =
    ChangeNotifierProvider<AuthController>((ref) {
  final c = AuthController(ref);
  ref.onDispose(c.dispose);
  return c;
});
