import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/admin_ai_config_repository.dart';
import '../../data/admin_operations_repository.dart';
import '../admin_ai_labels.dart';

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
              ? l10n.modelDiscoveryCompleted(
                  result['discovered'] as int? ?? 0,
                  result['added'] as int? ?? 0,
                )
              : l10n.providerReachable(result['model_count'] as int? ?? 0);
        });
      }
    } catch (error) {
      ref.invalidate(adminConsoleProvider);
      if (mounted) {
        setState(
          () => _error = error is AdminAiOperationException
              ? adminAiErrorLabel(error.code, l10n)
              : discover
              ? l10n.modelDiscoveryFailed
              : l10n.providerTestFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _configureModel(AdminModelRecord model) async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    var enabled = model.enabled;
    var scope = model.runtimeScope;
    var priority = model.priority.toDouble();
    var saving = false;
    String? error;
    setState(() => _submitting = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(model.displayName),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.enabled),
                      value: enabled,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => enabled = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: scope,
                      decoration: InputDecoration(labelText: l10n.runtimeScope),
                      items: [
                        for (final value in ['user', 'admin', 'both'])
                          DropdownMenuItem(
                            value: value,
                            child: Text(adminRuntimeScopeLabel(value, l10n)),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => scope = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    Text('${l10n.priority} ${priority.round()}'),
                    Slider(
                      value: priority,
                      min: 0,
                      max: 1000,
                      divisions: 100,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => priority = value),
                    ),
                    if (error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
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
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(
                                () => error = l10n.modelSaveFailed,
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
      final repository = ref.read(adminAiConfigRepositoryProvider);
      final providerId = await repository.configureProvider(
        slug: _slugCtrl.text.trim(),
        displayName: _displayNameCtrl.text.trim(),
        adapter: _adapter,
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKey: _apiKeyCtrl.text.trim(),
        enabled: _enabled,
        priority: _priority,
      );
      _apiKeyCtrl.clear();
      // Saving is successful even if upstream discovery fails; preserve that
      // distinction so credentials are not repeatedly submitted.
      var discoveryFailed = false;
      try {
        await repository.discoverModels(providerId);
      } catch (_) {
        discoveryFailed = true;
      }
      ref.invalidate(adminConsoleProvider);
      if (mounted) {
        setState(() {
          _status = discoveryFailed
              ? AppLocalizations.of(context).providerSavedDiscoveryFailed
              : AppLocalizations.of(context).providerSaved;
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
                                          '${provider.adapter}\n${provider.baseUrl}\n${l10n.runtimeScope}: ${adminRuntimeScopeLabel(provider.runtimeScope, l10n)}',
                                        ),
                                      ),
                                      trailing: Tooltip(
                                        message: provider.credentialRejected
                                            ? l10n.aiCredentialRejected
                                            : provider.credentialConfigured
                                            ? l10n.credentialConfigured
                                            : l10n.credentialMissing,
                                        child: Icon(
                                          provider.credentialRejected
                                              ? Icons.warning_amber_outlined
                                              : provider.credentialConfigured
                                              ? Icons.key_outlined
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
                                          '${adminRuntimeScopeLabel(model.runtimeScope, l10n)} · ${l10n.priority} ${model.priority}${model.available ? '' : ' · ${l10n.unavailable}'}',
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
                          return l10n.lowercaseSlugHint;
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
                      label: l10n.baseUrl,
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
