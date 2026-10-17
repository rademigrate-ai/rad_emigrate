import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/inline_alert.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/localized_error_message.dart';
import '../../../../core/routing/auth_redirect.dart';
import '../providers/auth_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/locale_controller.dart';
import '../../../../core/widgets/premium_visuals.dart';

class ProfileCompletionPage extends ConsumerStatefulWidget {
  const ProfileCompletionPage({super.key, this.destination});

  final String? destination;

  @override
  ConsumerState<ProfileCompletionPage> createState() =>
      _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends ConsumerState<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nationalityCtrl.dispose();
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
          .completeProfile(
            fullName: _nameCtrl.text.trim(),
            nationality: _nationalityCtrl.text.trim().isEmpty
                ? null
                : _nationalityCtrl.text.trim(),
          );
      if (mounted) context.go(restoredProtectedDestination(widget.destination));
    } catch (e) {
      if (mounted) {
        setState(() => _error = localizedAuthError(e, l10n));
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

    return AuthCinematicFrame(
      backFallback: '/dashboard',
      eyebrow: l10n.profileCompletionTitle,
      title: l10n.brandIntroTitle,
      body: l10n.brandIntroBody,
      localeControl: Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          const AppBackButton(fallback: '/dashboard'),
          TextButton.icon(
            icon: const Icon(Icons.language_outlined),
            label: Text(
              Localizations.localeOf(context).languageCode == 'fa'
                  ? l10n.english
                  : l10n.persian,
            ),
            onPressed: () =>
                ref.read(localeControllerProvider.notifier).toggle(),
          ),
        ],
      ),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileCompletionTitle,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileCompletionSubtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.aboutYou, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _nameCtrl,
                    label: l10n.fullName,
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? l10n.required
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _nationalityCtrl,
                    label: l10n.nationalityOptional,
                    prefixIcon: Icons.public_outlined,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InlineAlert(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: l10n.saveAndContinue,
                    loading: loading,
                    onPressed: loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
