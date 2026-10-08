import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/password_recovery.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/rad_brand.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email: _emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _sent = true;
          _loading = false;
        });
      }
    } catch (error) {
      // A failed request must remain retryable. Keep the message account-neutral
      // and never show backend details or claim that an email was sent.
      if (mounted) {
        final rateLimited = isPasswordRecoveryRateLimited(error);
        setState(() {
          _loading = false;
          _error = rateLimited
              ? l10n.passwordResetRateLimited
              : l10n.passwordResetFailed;
        });
        if (rateLimited) _startCooldown();
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
        return;
      }
      setState(() => _cooldownSeconds -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final coolingDown = _cooldownSeconds > 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 440 : 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: RadBrand(size: RadBrandSize.medium)),
                    const SizedBox(height: 24),
                    Text(
                      l10n.resetPassword,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_sent)
                      Text(
                        l10n.passwordResetSent,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      )
                    else ...[
                      Text(
                        l10n.passwordResetSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        controller: _emailCtrl,
                        label: l10n.email,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.required;
                          }
                          if (!v.contains('@')) return l10n.invalidEmail;
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        label: l10n.sendResetLink,
                        loading: _loading,
                        onPressed: _loading || coolingDown ? null : _submit,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(l10n.backToSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
