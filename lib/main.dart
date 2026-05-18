import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'app.dart';
import 'core/providers/bootstrap_providers.dart';
import 'core/services/hive_service.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.init();
  final hive = HiveService();
  await hive.init();
  final supabase = await SupabaseBootstrap.init();
  runApp(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(hive),
        supabaseClientProvider.overrideWithValue(supabase),
      ],
      child: const TemariApp(),
    ),
  );
}
