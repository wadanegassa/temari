import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/bootstrap_providers.dart';
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

  Future<void> signIn(String email, String password) async {
    await _sb.signIn(email: email, password: password);
    anonymous = false;
    await _hive.patchSettings({'anonymous': false});
    await _sb.pullRemoteIntoHive();
    notifyListeners();
  }

  Future<void> signUp(String email, String password, String? name) async {
    await _sb.signUp(email: email, password: password, displayName: name);
    anonymous = false;
    await _hive.patchSettings({'anonymous': false});
    notifyListeners();
  }

  Future<void> signOut() async {
    await _sb.signOut();
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
