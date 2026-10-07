import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/localized_error_message.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/rad_brand.dart';
import '../../../../core/widgets/app_entrance.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

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
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() => _error = localizedAuthError(e, l10n));
      }
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
      if (mounted) {
        context.go('/otp?identifier=${Uri.encodeComponent(email)}');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedAuthError(
            error,
            l10n,
            context: AuthErrorContext.otp,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loading = ref.watch(authControllerProvider).isLoading || _submitting;
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final theme = Theme.of(context);

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.signIn, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(l10n.signInSubtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 36),
          AppTextField(
            controller: _identifierCtrl,
            label: l10n.email,
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return l10n.required;
              if (!value.contains('@')) return l10n.invalidEmail;
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordCtrl,
            label: l10n.password,
            prefixIcon: Icons.lock_outline,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.isEmpty) ? l10n.required : null,
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
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
    );
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RadBrand(size: RadBrandSize.large, darkSurface: true),
        const SizedBox(height: 40),
        Text(
          l10n.brandIntroTitle,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.brandIntroBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFBCC7D6),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _BrandFeature(icon: Icons.public_outlined, label: l10n.visa),
            _BrandFeature(icon: Icons.assignment_outlined, label: l10n.cases),
            _BrandFeature(icon: Icons.newspaper_outlined, label: l10n.feed),
          ],
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                child: ColoredBox(
                  color: AppColors.navy,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: brand,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 40 : 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AppEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              icon: const Icon(Icons.language),
                              label: Text(
                                ref.watch(localeControllerProvider).isRtl
                                    ? 'English'
                                    : 'فارسی',
                              ),
                              onPressed: () => ref
                                  .read(localeControllerProvider.notifier)
                                  .toggle(),
                            ),
                          ),
                          if (!wide) ...[
                            const Center(
                              child: RadBrand(size: RadBrandSize.medium),
                            ),
                            const SizedBox(height: 36),
                          ],
                          form,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: Colors.white),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white)),
    ],
  );
}
