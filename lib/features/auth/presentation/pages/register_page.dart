import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
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

  String _mapError(Object e, AppLocalizations l10n) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('connection')) {
      return l10n.errorNetwork;
    }
    if (raw.contains('already') || raw.contains('registered')) {
      return l10n.errorAuthInvalid;
    }
    return l10n.errorGeneric;
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
          '/otp?identifier=${Uri.encodeComponent(_emailCtrl.text.trim())}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _mapError(e, l10n));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(authControllerProvider).isLoading || _submitting;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.createAccount)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.signUp, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      l10n.signInSubtitle,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(value: 0.33, minHeight: 6),
                    const SizedBox(height: 24),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.createAccount,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailCtrl,
                            label: l10n.email,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return l10n.required;
                              }
                              if (!v.contains('@')) return l10n.invalidEmail;
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _phoneCtrl,
                            label: l10n.phone,
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: (v) {
                              final digits = (v ?? '').replaceAll(
                                RegExp(r'[^0-9+]'),
                                '',
                              );
                              if (digits.length < 8) {
                                return l10n.required;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _passwordCtrl,
                            label: l10n.password,
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? l10n.showPassword
                                  : l10n.hidePassword,
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return l10n.passwordTooShort;
                              }
                              return null;
                            },
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error case final error?) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          AppButton(
                            label: l10n.next,
                            loading: loading,
                            onPressed: loading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: l10n.alreadyHaveAccount,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.go('/login'),
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
