import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads default values from [assets/dotenv] as a template, then merges a
/// root `.env` file when present (desktop / `flutter run` from project root).
/// Falls back to `--dart-define=KEY=value` for CI and release builds.
class AppEnv {
  AppEnv._();

  static Future<void> init() async {
    await dotenv.load(fileName: 'assets/dotenv', isOptional: true);
    await dotenv.load(fileName: '.env', mergeWith: dotenv.env, isOptional: true);
    if (!kIsWeb) {
      await _mergeRootDotEnv();
    }
  }

  static Future<void> _mergeRootDotEnv() async {
    try {
      final f = File('.env');
      if (!await f.exists()) return;
      final lines = await f.readAsLines();
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eq = line.indexOf('=');
        if (eq <= 0) continue;
        final key = line.substring(0, eq).trim();
        var value = line.substring(eq + 1).trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        if (key.isNotEmpty) {
          dotenv.env[key] = value;
        }
      }
    } on Object {
      // Ignore missing permissions or invalid paths on some embedders.
    }
  }

  static String get geminiApiKey {
    final v = dotenv.env['GEMINI_API_KEY']?.trim();
    if (v != null && v.isNotEmpty) return v;
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  static String get geminiModel {
    final v = dotenv.env['GEMINI_MODEL']?.trim();
    if (v != null && v.isNotEmpty) return v;
    return const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.5-flash');
  }

  static String get supabaseUrl {
    final v = dotenv.env['SUPABASE_URL']?.trim();
    if (v != null && v.isNotEmpty) return v;
    return const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }

  static String get supabaseAnonKey {
    final v = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    if (v != null && v.isNotEmpty) return v;
    return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }
}
