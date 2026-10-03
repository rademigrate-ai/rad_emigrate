dart format --output=show lib/features/auth/presentation/pages/otp_page.dart
shell: /usr/bin/bash -e {0}
env:
  FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.47.6-x64/flutter
  PUB_CACHE: /home/runner/.pub-cache
##[endgroup]
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

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

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = widget.identifier?.trim() ?? '';
    final otp = _otpCtrl.text.trim();
    if (identifier.isEmpty || !identifier.contains('@')) {
      setState(
        () => _error = 'Return to sign up and enter your email address.',
      );
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
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
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _resend() async {
    final identifier = widget.identifier?.trim() ?? '';
    if (identifier.isEmpty || !identifier.contains('@')) {
      setState(
        () => _error = 'Return to sign up and enter your email address.',
      );
      return;
    }
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
        setState(() => _notice = 'A new verification code was sent.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A quick security check',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code sent to your email address.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '------',
                          ),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: const TextStyle(color: AppColors.error),
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
                              style: TextStyle(color: AppColors.success),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Verify code',
                          loading: loading,
                          onPressed: _submit,
                        ),
                        TextButton(
                          onPressed: loading || _resending ? null : _resend,
                          child: _resending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Resend code'),
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
Formatted 1 file (1 changed) in 0.01 seconds.
