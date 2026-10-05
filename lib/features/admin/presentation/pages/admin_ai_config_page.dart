import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_ai_config_repository.dart';
import '../../data/admin_operations_repository.dart';

class AdminAiConfigPage extends ConsumerStatefulWidget {
  const AdminAiConfigPage({super.key});

  @override
  ConsumerState<AdminAiConfigPage> createState() => _AdminAiConfigPageState();
}

class _AdminAiConfigPageState extends ConsumerState<AdminAiConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _slugCtrl = TextEditingController(text: 'openrouter');
  final _displayNameCtrl = TextEditingController(text: 'OpenRouter');
  final _baseUrlCtrl = TextEditingController(
    text: 'https://openrouter.ai/api/v1',
  );
  final _apiKeyCtrl = TextEditingController();
  String _adapter = 'openai_compatible';
  bool _enabled = true;
  int _priority = 10;
  bool _submitting = false;
  bool _editingExisting = false;
  String? _status;
  String? _error;

  void _editProvider(AdminProviderRecord provider) {
    setState(() {
      _editingExisting = true;
      _slugCtrl.text = provider.slug;
      _displayNameCtrl.text = provider.displayName;
      _baseUrlCtrl.text = provider.baseUrl;
      _apiKeyCtrl.clear();
      _adapter = provider.adapter;
      _enabled = provider.enabled;
      _priority = provider.priority;
      _status = null;
      _error = null;
    });
  }

  Future<void> _providerAction(
    AdminProviderRecord provider, {
    required bool discover,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
      _status = null;
    });
    try {
      final repository = ref.read(adminAiConfigRepositoryProvider);
      final result = discover
          ? await repository.discoverModels(provider.id)
          : await repository.testProvider(provider.id);
      ref.invalidate(adminConsoleProvider);
      if (mounted) {
        setState(() {
          _status = discover
              ? 'Model discovery completed: ${result['discovered'] ?? 0} found, ${result['added'] ?? 0} added.'
              : 'Provider is reachable (${result['model_count'] ?? 0} models visible).';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = discover
              ? l10n.modelDiscoveryFailed
              : l10n.providerTestFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _configureModel(AdminModelRecord model) async {
    final l10n = AppLocalizations.of(context);
    var enabled = model.enabled;
    var scope = model.runtimeScope;
    var priority = model.priority.toDouble();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(model.displayName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.enabled),
                value: enabled,
                onChanged: (value) => setDialogState(() => enabled = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: scope,
                decoration: InputDecoration(labelText: l10n.runtimeScope),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('USER')),
                  DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
                  DropdownMenuItem(value: 'both', child: Text('BOTH')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => scope = value);
                },
              ),
              const SizedBox(height: 12),
              Text('Priority ${priority.round()}'),
              Slider(
                value: priority,
                min: 0,
                max: 1000,
                divisions: 100,
                onChanged: (value) => setDialogState(() => priority = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    await ref
        .read(adminAiConfigRepositoryProvider)
        .configureModel(
          modelId: model.id,
          enabled: enabled,
          runtimeScope: scope,
          priority: priority.round(),
          maxOutputTokens: model.maxOutputTokens,
        );
    ref.invalidate(adminConsoleProvider);
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _displayNameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _status = null;
    });
    try {
      await ref
          .read(adminAiConfigRepositoryProvider)
          .configureProvider(
            slug: _slugCtrl.text.trim(),
            displayName: _displayNameCtrl.text.trim(),
            adapter: _adapter,
            baseUrl: _baseUrlCtrl.text.trim(),
            apiKey: _apiKeyCtrl.text.trim(),
            enabled: _enabled,
            priority: _priority,
          );
      _apiKeyCtrl.clear();
      ref.invalidate(adminConsoleProvider);
      if (mounted) {
        setState(() {
          _status = AppLocalizations.of(context).providerSaved;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).providerSaveFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final console = ref.watch(adminConsoleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAiConfig)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.providerModelConnection,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.credentialsServerOnly),
              const SizedBox(height: 20),
              console.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(l10n.configurationUnavailable),
                data: (data) => data.providers.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(l10n.noProviderConfigured),
                        ),
                      )
                    : Column(
                        children: [
                          for (final provider in data.providers)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    ListTile(
                                      onTap: () => _editProvider(provider),
                                      leading: Icon(
                                        provider.enabled
                                            ? Icons.smart_toy_outlined
                                            : Icons.pause_circle_outline,
                                      ),
                                      title: Text(provider.displayName),
                                      subtitle: Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          '${provider.adapter}\n${provider.baseUrl}\nScope: ${provider.runtimeScope.toUpperCase()}',
                                        ),
                                      ),
                                      trailing: Tooltip(
                                        message: provider.credentialConfigured
                                            ? l10n.credentialConfigured
                                            : l10n.credentialMissing,
                                        child: Icon(
                                          provider.credentialConfigured
                                              ? Icons.verified_user_outlined
                                              : Icons.key_off_outlined,
                                        ),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _submitting
                                              ? null
                                              : () => _providerAction(
                                                  provider,
                                                  discover: false,
                                                ),
                                          icon: const Icon(
                                            Icons.health_and_safety_outlined,
                                          ),
                                          label: Text(l10n.testProvider),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: _submitting
                                              ? null
                                              : () => _providerAction(
                                                  provider,
                                                  discover: true,
                                                ),
                                          icon: const Icon(
                                            Icons.manage_search_outlined,
                                          ),
                                          label: Text(l10n.discoverModels),
                                        ),
                                      ],
                                    ),
                                    for (final model in data.models.where(
                                      (model) =>
                                          model.providerId == provider.id,
                                    ))
                                      ListTile(
                                        dense: true,
                                        onTap: () => _configureModel(model),
                                        leading: Icon(
                                          model.enabled && model.available
                                              ? Icons.check_circle_outline
                                              : Icons.pause_circle_outline,
                                        ),
                                        title: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(model.slug),
                                        ),
                                        subtitle: Text(
                                          '${model.runtimeScope.toUpperCase()} · priority ${model.priority}${model.available ? '' : ' · unavailable'}',
                                        ),
                                        trailing: const Icon(Icons.tune),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              Text(l10n.addOrUpdateProvider, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _slugCtrl,
                      label: l10n.slugLabel,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return l10n.required;
                        }
                        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                          return 'Use lowercase letters, digits, underscore';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _displayNameCtrl,
                      label: l10n.displayName,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.required
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.adapterType,
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _adapter,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'openai_compatible',
                              child: Text(
                                'openai_compatible',
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'anthropic',
                              child: Text(
                                'anthropic',
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'gemini',
                              child: Text(
                                'gemini',
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _adapter = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _baseUrlCtrl,
                      label: 'Base URL',
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return l10n.required;
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty) {
                          return l10n.publicHttpsOnly;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _apiKeyCtrl,
                      label: l10n.apiKeyWriteOnly,
                      textDirection: TextDirection.ltr,
                      obscureText: true,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if ((!_editingExisting && value.length < 8) ||
                            (value.isNotEmpty && value.length < 8)) {
                          return l10n.keyMinimumEight;
                        }
                        return null;
                      },
                    ),
                    if (_editingExisting)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l10n.keepCurrentCredential),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.enabled),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.priority),
                      subtitle: Text('$_priority'),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          min: 1,
                          max: 200,
                          divisions: 199,
                          value: _priority.toDouble(),
                          onChanged: (v) =>
                              setState(() => _priority = v.round()),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    if (_status != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _status!,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: l10n.saveProvider,
                      loading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
