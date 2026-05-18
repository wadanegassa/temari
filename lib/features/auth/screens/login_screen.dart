import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/temari_text_field.dart';
import '../providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _signup = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      if (_signup) {
        await ref.read(authControllerProvider).signUp(
              _email.text.trim(),
              _password.text,
              _name.text.trim().isEmpty ? null : _name.text.trim(),
            );
      } else {
        await ref.read(authControllerProvider).signIn(
              _email.text.trim(),
              _password.text,
            );
      }
      await ref.read(settingsControllerProvider).setOnboardingComplete(true);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _skip() async {
    await ref.read(authControllerProvider).continueWithoutAccount();
    await ref.read(settingsControllerProvider).setOnboardingComplete(true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Text(AppStrings.get('app_name', lang), style: AppTextStyles.h1),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(AppStrings.get('sign_in', lang)),
                  selected: !_signup,
                  onSelected: (_) => setState(() => _signup = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(AppStrings.get('sign_up', lang)),
                  selected: _signup,
                  onSelected: (_) => setState(() => _signup = true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_signup) ...[
              TemariTextField(controller: _name, hint: AppStrings.get('display_name', lang)),
              const SizedBox(height: 12),
            ],
            TemariTextField(
              controller: _email,
              hint: AppStrings.get('email', lang),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TemariTextField(
              controller: _password,
              hint: AppStrings.get('password', lang),
              obscure: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 24),
            TemariButton(
              label: _signup
                  ? AppStrings.get('sign_up', lang)
                  : AppStrings.get('sign_in', lang),
              onPressed: _submit,
            ),
            TextButton(
              onPressed: _skip,
              child: Text(
                AppStrings.get('continue_without', lang),
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
