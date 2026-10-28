import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/rad_loading.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_operations_repository.dart';
import '../../domain/research_source_url.dart';

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
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _university;

  String _selectedSourceType = 'government';
  String _selectedCountryCode = 'CA';
  String _selectedInterval = 'daily';
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _url = TextEditingController();
    _university = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _university.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri?.scheme == 'http') return l10n.sourceHttpRejected;
    if (uri?.hasQuery == true) return l10n.sourceQueryRejected;
    return parseResearchSourceUrl(value ?? '') == null ? l10n.invalidUrl : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final parsedUri = parseResearchSourceUrl(_url.text);
    if (parsedUri == null) {
      setState(() => _error = l10n.invalidUrl);
      return;
    }

    final address = canonicalResearchSourceUrl(parsedUri);

    final data = ref.read(adminConsoleProvider).valueOrNull;
    if (data?.researchSources.any((source) {
          final uri = parseResearchSourceUrl(source.baseUrl);
          return uri != null && canonicalResearchSourceUrl(uri) == address;
        }) ==
        true) {
      setState(() => _error = l10n.sourceDuplicate);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Admin-entered sources are explicitly designated 'admin_defined' (unverified)
      // Never imply that a manually entered source is automatically authoritative.
      await ref
          .read(adminOperationsRepositoryProvider)
          .createResearchSource(
            displayName: _name.text.trim(),
            baseUrl: address,
            sourceType: _selectedSourceType,
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
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

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
                  const SizedBox(height: 16),

                  // 1. Source Name (TextFormField index 0)
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

                  // 2. Source Address URL (TextFormField index 1)
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

                  // 3. Source Type Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedSourceType,
                    decoration: InputDecoration(
                      labelText: isFa ? 'نوع منبع' : 'Source Type Category',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'government',
                        child: Text(
                          isFa
                              ? 'دولتی مهاجرت'
                              : 'Official Government Department',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'embassy',
                        child: Text(
                          isFa ? 'سفارت / کنسولگری' : 'Embassy / Consulate',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'university',
                        child: Text(
                          isFa ? 'دانشگاه رسمی' : 'Official University',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'professional_body',
                        child: Text(
                          isFa
                              ? 'سازمان ارزیابی مدارک'
                              : 'Professional Recognition Body',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'admin_reference',
                        child: Text(
                          isFa ? 'منبع سفارشی مدیر' : 'Admin Custom Reference',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _selectedSourceType = v ?? 'government',
                          ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Country Code Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedCountryCode,
                    decoration: InputDecoration(
                      labelText: isFa ? 'کشور مربوطه' : 'Associated Country',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CA',
                        child: Text(
                          '🇨🇦 کانادا (Canada)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'DE',
                        child: Text(
                          '🇩🇪 آلمان (Germany)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'AU',
                        child: Text(
                          '🇦🇺 استرالیا (Australia)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'UK',
                        child: Text(
                          '🇬🇧 انگلستان (UK)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'US',
                        child: Text(
                          '🇺🇸 ایالات متحده (USA)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'GLOBAL',
                        child: Text(
                          '🌍 بین‌المللی (Global)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) =>
                              setState(() => _selectedCountryCode = v ?? 'CA'),
                  ),
                  if (_selectedSourceType == 'university') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _university,
                      enabled: !_saving,
                      maxLength: 150,
                      decoration: InputDecoration(
                        labelText: isFa
                            ? 'نام دانشگاه مرتبط'
                            : 'Associated University Name',
                        hintText: isFa
                            ? 'مثال: دانشگاه تورنتو (U of T)'
                            : 'e.g. University of Toronto',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedInterval,
                    decoration: InputDecoration(
                      labelText: isFa
                          ? 'بازه زمانی پایش دوره‌ای'
                          : 'Monitoring Check Interval',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'every6h',
                        child: Text(
                          isFa ? 'هر ۶ ساعت (Every 6 hours)' : 'Every 6 hours',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'every12h',
                        child: Text(
                          isFa
                              ? 'هر ۱۲ ساعت (Every 12 hours)'
                              : 'Every 12 hours',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text(
                          isFa
                              ? 'روزانه - هر ۲۴ ساعت (Daily / 24h)'
                              : 'Daily (every 24 hours)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text(
                          isFa
                              ? 'هفتگی - هر ۷ روز (Weekly / 7 days)'
                              : 'Weekly (every 7 days)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) =>
                              setState(() => _selectedInterval = v ?? 'daily'),
                  ),
                  const SizedBox(height: 16),

                  // Disclaimer
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
                ? const SizedBox(width: 20, height: 20, child: RadPending())
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
