import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/localized_error_message.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) {
        context.go(
          '/otp?identifier=${Uri.encodeComponent(_emailCtrl.text.trim())}&mode=signup',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = localizedAuthError(
            e,
            l10n,
            context: AuthErrorContext.registration,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final loading = ref.watch(authControllerProvider).isLoading || _submitting;
    return AuthCinematicFrame(
      eyebrow: 'RAD • CREATE YOUR SPACE',
      title: l10n.brandIntroTitle,
      body: l10n.brandIntroBody,
      localeControl: TextButton.icon(
        icon: const Icon(Icons.language_outlined, size: 18),
        label: Text(
          ref.watch(localeControllerProvider).isRtl ? 'English' : 'فارسی',
        ),
        onPressed: () => ref.read(localeControllerProvider.notifier).toggle(),
      ),
      form: MotionReveal(
        offset: const Offset(0, 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EditorialKicker(index: '02', label: 'CREATE ACCOUNT'),
              const SizedBox(height: 16),
              Text(
                l10n.signUp,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 34,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.signUpSubtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: 0.33,
                  minHeight: 5,
                  color: AppColors.primaryRed,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 26),
              AppTextField(
                controller: _emailCtrl,
                label: l10n.email,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.required;
                  }
                  return value.contains('@') ? null : l10n.invalidEmail;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _phoneCtrl,
                label: l10n.phone,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) {
                  final digits = (value ?? '').replaceAll(
                    RegExp(r'[^0-9+]'),
                    '',
                  );
                  return digits.length < 8 ? l10n.required : null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _passwordCtrl,
                label: l10n.password,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (value) => value == null || value.length < 8
                    ? l10n.passwordTooShort
                    : null,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: l10n.next,
                icon: Icons.arrow_forward_rounded,
                loading: loading,
                onPressed: loading ? null : _submit,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: l10n.alreadyHaveAccount,
                variant: AppButtonVariant.ghost,
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
