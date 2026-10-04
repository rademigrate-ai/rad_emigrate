import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key, this.identifier});

  final String? identifier;

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpCtrl = TextEditingController();
  String? _error;
  String? _notice;
  bool _resending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  String _mapError(Object e, AppLocalizations l10n) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('expired') || raw.contains('invalid')) {
      return l10n.errorAuthInvalid;
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return l10n.errorNetwork;
    }
    return l10n.errorGeneric;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final identifier = widget.identifier?.trim() ?? '';
    final otp = _otpCtrl.text.trim();
    if (identifier.isEmpty || !identifier.contains('@')) {
      setState(() => _error = l10n.invalidEmail);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = l10n.required);
      return;
    }
    setState(() => _error = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(identifier: identifier, otp: otp);
      final session = ref.read(authControllerProvider).valueOrNull;
      if (mounted) {
        if (session != null && !session.profileComplete) {
          context.go('/profile-completion');
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = _mapError(e, l10n));
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    final identifier = widget.identifier?.trim() ?? '';
    if (identifier.isEmpty || !identifier.contains('@')) {
      setState(() => _error = l10n.invalidEmail);
      return;
    }
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _error = null;
      _notice = null;
      _resending = true;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendOtp(identifier: identifier);
      if (mounted) {
        setState(() => _notice = l10n.resendCode);
        _startCooldown();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _mapError(e, l10n));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(authControllerProvider).isLoading;
    final theme = Theme.of(context);
    final identifier = widget.identifier?.trim() ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l10n.otpTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.otpTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(l10n.otpSubtitle, style: theme.textTheme.bodyMedium),
                  if (identifier.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        identifier,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '------',
                            labelText: l10n.otpCode,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: TextStyle(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (_notice case final notice?) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              notice,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        AppButton(
                          label: l10n.verify,
                          loading: loading,
                          onPressed: loading ? null : _submit,
                        ),
                        TextButton(
                          onPressed: loading || _resending || _cooldown > 0
                              ? null
                              : _resend,
                          child: _resending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _cooldown > 0
                                      ? l10n.resendIn(_cooldown)
                                      : l10n.resendCode,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
