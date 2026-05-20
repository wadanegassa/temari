import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/scale_on_press.dart';
import '../../../shared/widgets/temari_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static final RegExp _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email like name@gmail.com, name@yahoo.com, or another valid address';
    }
    return null;
  }

  String _friendlyAuthError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('user not found') ||
          message.contains('email not confirmed')) {
        return 'Account not found yet. We will create it for you after this attempt.';
      }
      if (message.contains('already registered')) {
        return 'This account already exists. Try signing in instead.';
      }
      return error.message;
    }
    return text;
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isBusy = true;
      _inlineError = null;
    });

    final auth = ref.read(authControllerProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      Session? session;
      try {
        session = await auth.signIn(email, password);
      } on AuthException catch (signInError) {
        final msg = signInError.message.toLowerCase();
        if (msg.contains('invalid login credentials') || msg.contains('user not found')) {
          try {
            session = await auth.signUp(email, password, null);
          } on AuthException catch (signUpError) {
            final signUpMsg = signUpError.message.toLowerCase();
            if (signUpMsg.contains('already registered') || signUpMsg.contains('already exists')) {
              throw signInError;
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Check your email to verify your account, then sign in.'),
            backgroundColor: AppColors.accent,
          ),
        );
        return;
      }
      context.go('/home');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = _friendlyAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ScaleOnPress(
                    onTap: () => context.go('/chatbot'),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Temari Account',
                    style: AppTextStyles.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in to continue',
                      style: AppTextStyles.h1.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If your email is new, Temari will create the account automatically after the first sign-in attempt.',
                      style: AppTextStyles.body.copyWith(color: AppColors.inkMid),
                    ),
                    const SizedBox(height: 16),
                    _GoogleAuthButton(
                      onPressed: null,
                    ),
                    const SizedBox(height: 20),
                    if (_inlineError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _inlineError!,
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _AuthField(
                            controller: _emailController,
                            label: 'Email address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 12),
                          _AuthField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 6) return 'Use at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TemariButton(
                            label: _isBusy ? 'Please wait...' : 'Sign in',
                            onPressed: _isBusy ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.inkLight),
        filled: true,
        fillColor: AppColors.bgSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TemariButton(
      label: 'Continue with Google',
      variant: TemariButtonVariant.secondary,
      onPressed: onPressed,
    );
  }
}