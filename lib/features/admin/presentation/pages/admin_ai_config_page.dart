import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/rad_loading.dart';
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
  bool _obscureApiKey = true;
  bool _submitting = false;
  bool _syncingCatalogue = false;
  bool _modelDialogOpen = false;
  bool _editingExisting = false;
  bool _showAdvancedSettings = false;
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
      _showAdvancedSettings = true;
    });
  }

  Future<void> _syncCatalogues() async {
    setState(() {
      _syncingCatalogue = true;
      _status = null;
      _error = null;
    });
    try {
      final repository = ref.read(adminAiConfigRepositoryProvider);
      final result = await repository.syncAllCatalogues();
      ref.invalidate(adminConsoleProvider);
      if (mounted) {
        final syncedCount = result['synced_providers'] ?? result['providers_synced'] ?? 1;
        setState(() {
          _status = 'همگام‌سازی کاتالوگ با موفقیت انجام شد ($syncedCount ارائه‌دهنده بررسی شدند).';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'همگام‌سازی کاتالوگ مدل‌ها با خطا مواجه شد.';
        });
      }
    } finally {
      if (mounted) setState(() => _syncingCatalogue = false);
    }
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
    if (_submitting || _modelDialogOpen) return;
    final l10n = AppLocalizations.of(context);
    var enabled = model.enabled;
    var scope = model.runtimeScope;
    var priority = model.priority.toDouble();
    var saving = false;
    String? error;
    setState(() => _modelDialogOpen = true);
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
                          child: RadPending(),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _modelDialogOpen = false);
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

      if (!_editingExisting) {
        // Fast 2-field onboarding (Base URL + API Key)
        final result = await repository.onboardProviderTwoField(
          baseUrl: _baseUrlCtrl.text.trim(),
          apiKey: _apiKeyCtrl.text.trim(),
          displayName: _displayNameCtrl.text.trim(),
          slug: _slugCtrl.text.trim(),
        );
        _apiKeyCtrl.clear();
        ref.invalidate(adminConsoleProvider);
        if (mounted) {
          final count = result['models_count'] ?? result['discovered'] ?? 0;
          setState(() {
            _status = 'ارائه‌دهنده با موفقیت متصل و $count مدل شناسایی گردید.';
          });
        }
      } else {
        // Update existing provider
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
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('مدیریت ارائه‌دهندگان هوش مصنوعی'),
        actions: [
          IconButton(
            tooltip: 'همگام‌سازی فوری کاتالوگ مدل‌ها',
            icon: _syncingCatalogue
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncingCatalogue ? null : _syncCatalogues,
          ),
        ],
      ),
      body: Directionality(
        textDirection: Directionality.of(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 8-Hour Sync Status Card
                  _buildCatalogueSyncCard(),

                  const SizedBox(height: 20),

                  // 2. Active Configured Providers Card
                  Text(
                    l10n.providerModelConnection,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.credentialsServerOnly),
                  const SizedBox(height: 16),

                  console.when(
                    loading: () => Center(
                      child: RadInlineLoading(label: l10n.loadingOperational),
                    ),
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
                                _buildProviderCard(provider, data.models, l10n),
                            ],
                          ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Smart Routing Information Card (No manual model ranking required)
                  _buildSmartRoutingNotice(),

                  const SizedBox(height: 24),

                  // 4. Two-Field Add Provider Form
                  _buildAddProviderCard(l10n, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogueSyncCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.update, color: AppColors.teal, size: 22),
          ),
          title: const Text(
            'همگام‌سازی خودکار کاتالوگ مدل‌ها (هر ۸ ساعت)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'سرویس هوشمند راد به صورت دوره‌ای مدل‌های جدید ارائه‌دهندگان را کشف و سلامت اتصال آن‌ها را می‌سنجد.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            ),
          ),
          trailing: FilledButton.tonalIcon(
            onPressed: _syncingCatalogue ? null : _syncCatalogues,
            icon: _syncingCatalogue
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 16),
            label: const Text('همگام‌سازی فوری'),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartRoutingNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.15)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alt_route, color: AppColors.navy, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مسیریابی هوشمند و خودکار مدل‌ها',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'موتور ارکستراسیون راد بر اساس هزینه، تاخیر، پیچیدگی سوال و نوع فایل، مدل بهینه را به صورت خودکار انتخاب می‌کند. اولویت‌بندی دستی مدل‌ها توسط مدیر لازم نیست.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(
    AdminProviderRecord provider,
    List<AdminModelRecord> allModels,
    AppLocalizations l10n,
  ) {
    Color statusColor;
    String statusText;

    if (!provider.enabled) {
      statusColor = AppColors.textSecondary;
      statusText = 'غیرفعال';
    } else if (provider.credentialRejected) {
      statusColor = AppColors.error;
      statusText = 'کلید نامعتبر';
    } else {
      statusColor = AppColors.teal;
      statusText = 'متصل و فعال';
    }

    final providerModels =
        allModels.where((m) => m.providerId == provider.id).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provider.enabled
                      ? Icons.cloud_done
                      : Icons.pause_circle_outline,
                  color: statusColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          provider.baseUrl,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'ویرایش مشخصات',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _editProvider(provider),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => _providerAction(provider, discover: false),
                  icon: const Icon(Icons.health_and_safety_outlined, size: 16),
                  label: Text(l10n.testProvider),
                ),
                OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => _providerAction(provider, discover: true),
                  icon: const Icon(Icons.manage_search_outlined, size: 16),
                  label: Text(l10n.discoverModels),
                ),
              ],
            ),

            if (providerModels.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'مدل‌های شناسایی‌شده (${providerModels.length} مدل):',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final model in providerModels)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _configureModel(model),
                  leading: Icon(
                    model.enabled && model.available
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    size: 18,
                    color: model.enabled ? AppColors.teal : AppColors.textSecondary,
                  ),
                  title: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(model.slug),
                  ),
                  subtitle: Text(
                    '${adminRuntimeScopeLabel(model.runtimeScope, l10n)} · اولویت ${model.priority}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.tune, size: 16),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddProviderCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppColors.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingExisting
                          ? 'به‌روزرسانی ارائه‌دهنده هوش مصنوعی'
                          : 'افزودن ارائه‌دهنده جدید هوش مصنوعی (تنها ۲ فیلد)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'تنها آدرس پایه (Base URL) و کلید دسترسی (API Key) را وارد کنید. پروتکل، ظرفیت و مدل‌ها به صورت خودکار شناسایی می‌شوند.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Field 1: Base URL
              AppTextField(
                controller: _baseUrlCtrl,
                label: l10n.baseUrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return l10n.required;
                  final uri = Uri.tryParse(value);
                  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
                    return l10n.publicHttpsOnly;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Field 2: API Key (Masked with visibility toggle)
              TextFormField(
                controller: _apiKeyCtrl,
                obscureText: _obscureApiKey,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.apiKeyWriteOnly,
                  hintText: 'sk-...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
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
                  child: Text(
                    l10n.keepCurrentCredential,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),

              // Expandable Advanced Options
              const SizedBox(height: 10),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _showAdvancedSettings,
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'تنظیمات پیشرفته اختیاری (نام نمایشی، آداپتور، اسلاگ)',
                    style: TextStyle(fontSize: 12, color: AppColors.navy),
                  ),
                  children: [
                    AppTextField(
                      controller: _displayNameCtrl,
                      label: l10n.displayName,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.required
                          : null,
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _slugCtrl,
                      label: l10n.slugLabel,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return l10n.required;
                        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                          return l10n.lowercaseSlugHint;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'پروتکل ارتباطی (Adapter)',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _adapter,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'openai_compatible',
                              child: Text('openai_compatible', textDirection: TextDirection.ltr),
                            ),
                            DropdownMenuItem(
                              value: 'gemini',
                              child: Text('gemini', textDirection: TextDirection.ltr),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _adapter = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.enabled),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!, style: const TextStyle(color: AppColors.teal)),
              ],
              const SizedBox(height: 16),

              AppButton(
                label: _editingExisting ? l10n.saveProvider : 'اتصال و شناسایی خودکار مدل‌ها',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
