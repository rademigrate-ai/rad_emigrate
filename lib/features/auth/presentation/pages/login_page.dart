import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/localized_error_message.dart';
import '../../../../core/routing/auth_redirect.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/rad_earth_bird_scene.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.destination});

  final String? destination;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
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
          .login(
            identifier: _identifierCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) context.go(restoredProtectedDestination(widget.destination));
    } catch (e) {
      if (mounted) setState(() => _error = localizedAuthError(e, l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueWithOtp() async {
    final l10n = AppLocalizations.of(context);
    final email = _identifierCtrl.text.trim();
    if (_submitting) return;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = l10n.invalidEmail);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendOtp(identifier: email);
      if (mounted) context.go('/otp?identifier=${Uri.encodeComponent(email)}');
    } catch (error) {
      if (mounted) {
        final message = error.toString().toLowerCase();
        var mapped = localizedAuthError(
          error,
          l10n,
          context: AuthErrorContext.otp,
        );
        try {
          final code = '${(error as dynamic).code ?? ''}'.toLowerCase();
          if (code.contains('otp_disabled') ||
              message.contains('otp_disabled')) {
            mapped = l10n.smsAuthUnavailable;
          }
        } catch (_) {
          if (message.contains('otp_disabled')) {
            mapped = l10n.smsAuthUnavailable;
          }
        }
        setState(() => _error = mapped);
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
    final viewport = MediaQuery.sizeOf(context);
    final wide = viewport.width >= 860;
    // Keep the dimensional Earth prominent without overflowing short laptops.
    final heroSize = wide
        ? (viewport.height * 0.43).clamp(240.0, 400.0)
        : 174.0;
    return AuthCinematicFrame(
      eyebrow: 'RAD • IMMIGRATION JOURNEY',
      title: l10n.brandIntroTitle,
      body: l10n.brandIntroBody,
      heroVisual: RadEarthBirdScene(
        variant: RadEarthBirdVariant.loginHero,
        semanticLabel: l10n.appTitle,
        size: heroSize,
      ),
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
              const EditorialKicker(index: '02', label: 'ACCESS PORTAL'),
              const SizedBox(height: 16),
              Text(
                l10n.signIn,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 34,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.signInSubtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 30),
              AppTextField(
                controller: _identifierCtrl,
                label: l10n.email,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return l10n.required;
                  return email.contains('@') ? null : l10n.invalidEmail;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _passwordCtrl,
                label: l10n.password,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.required : null,
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 14),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: l10n.signIn,
                icon: Icons.arrow_forward_rounded,
                loading: loading,
                onPressed: loading ? null : _submit,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.createAccount,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/register'),
              ),
              TextButton(
                onPressed: loading ? null : _continueWithOtp,
                child: Text(l10n.continueWithOtp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
