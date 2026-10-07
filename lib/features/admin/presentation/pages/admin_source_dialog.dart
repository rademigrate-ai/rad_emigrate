import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';

Future<void> showAdminSourceDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const AdminSourceDialog(),
);

class AdminSourceDialog extends ConsumerStatefulWidget {
  const AdminSourceDialog({super.key});
  @override
  ConsumerState<AdminSourceDialog> createState() => _AdminSourceDialogState();
}

class _AdminSourceDialogState extends ConsumerState<AdminSourceDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri?.scheme == 'http') return l10n.sourceHttpRejected;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return l10n.invalidUrl;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.local') ||
        host.endsWith('.localhost')) {
      return l10n.invalidUrl;
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final address = _url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final data = ref.read(adminConsoleProvider).valueOrNull;
    if (data?.researchSources.any((source) => source.baseUrl == address) ==
        true) {
      setState(() => _error = l10n.sourceDuplicate);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminOperationsRepositoryProvider)
          .createResearchSource(
            displayName: _name.text.trim(),
            baseUrl: address,
            sourceType: 'external',
            trustClass: 'admin_defined',
            runtimeScope: 'admin',
          );
      ref.invalidate(adminConsoleProvider);
      ref.invalidate(adminSnapshotProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.sourceSavedDisabled)));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PostgrestException && error.code == '23505'
              ? l10n.sourceDuplicate
              : l10n.sourceSaveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.addSource),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.researchNeverAutoPublishes,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 200,
                    decoration: InputDecoration(labelText: l10n.titleLabel),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? l10n.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _url,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l10n.sourceAddress,
                      hintText: 'https://',
                    ),
                    validator: _validateUrl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.sourceSavedDisabled,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
