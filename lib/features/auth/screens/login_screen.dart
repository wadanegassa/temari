import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/temari_text_field.dart';
import '../providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _signup = false;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailVal = _email.text.trim();
    final passwordVal = _password.text;
    final nameVal = _name.text.trim();

    if (emailVal.isEmpty || passwordVal.isEmpty || (_signup && nameVal.isEmpty)) {
      setState(() => _error = 'Please fill out all fields.');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      if (_signup) {
        await ref.read(authControllerProvider).signUp(
              emailVal,
              passwordVal,
              nameVal.isEmpty ? null : nameVal,
            );
      } else {
        await ref.read(authControllerProvider).signIn(
              emailVal,
              passwordVal,
            );
      }
      await ref.read(settingsControllerProvider).setOnboardingComplete(true);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '').replaceAll('state error: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _skip() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).continueWithoutAccount();
      await ref.read(settingsControllerProvider).setOnboardingComplete(true);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final tagline = lang == 'am'
        ? "ምርጥ የጥናት ጓደኛህ"
        : (lang == 'om' ? "Hiriyaa barnootaa kee" : "Your smartest study companion");

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Centered Temari wordmark
                Text(
                  'Temari',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tagline,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.inkLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),

                // Beautiful custom tab selection bar with sliding underline
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ScaleOnPress(
                          onTap: () => setState(() {
                            _signup = false;
                            _error = null;
                          }),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_signup ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_signup
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0C000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              AppStrings.get('sign_in', lang),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: !_signup ? AppColors.ink : AppColors.inkMid,
                                fontWeight: !_signup ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ScaleOnPress(
                          onTap: () => setState(() {
                            _signup = true;
                            _error = null;
                          }),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _signup ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _signup
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0C000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              AppStrings.get('sign_up', lang),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _signup ? AppColors.ink : AppColors.inkMid,
                                fontWeight: _signup ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Form fields container
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      if (_signup) ...[
                        TemariTextField(
                          controller: _name,
                          hint: AppStrings.get('display_name', lang),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TemariTextField(
                        controller: _email,
                        hint: AppStrings.get('email', lang),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TemariTextField(
                        controller: _password,
                        hint: AppStrings.get('password', lang),
                        obscure: true,
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),

                // Primary Button
                if (_isLoading)
                  const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                else
                  TemariButton(
                    label: _signup
                        ? (lang == 'am' ? 'ይመዝገቡ' : (lang == 'om' ? 'Galmaa\'i' : 'Create account'))
                        : AppStrings.get('sign_in', lang),
                    onPressed: _submit,
                  ),
                const SizedBox(height: 16),

                // Skip option
                if (!_isLoading)
                  ScaleOnPress(
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        AppStrings.get('continue_without', lang),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
