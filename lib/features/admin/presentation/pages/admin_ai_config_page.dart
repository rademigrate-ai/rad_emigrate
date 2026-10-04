import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
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
  String? _status;
  String? _error;

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
        final fa = Localizations.localeOf(context).languageCode == 'fa';
        setState(() {
          _status = fa
              ? 'Provider با موفقیت ذخیره شد. کلید در سرور نگهداری می‌شود و دیگر نمایش داده نمی‌شود.'
              : 'Provider saved. The credential is stored server-side and will not be shown again.';
        });
      }
    } catch (e) {
      if (mounted) {
        final fa = Localizations.localeOf(context).languageCode == 'fa';
        setState(() {
          _error = fa
              ? 'ذخیره تنظیمات ممکن نشد. نقش Super Admin و صحت ورودی‌ها را بررسی کنید.'
              : 'Could not save configuration. Confirm Super Admin role and input validity.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final console = ref.watch(adminConsoleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(fa ? 'تنظیمات هوش مصنوعی' : 'AI configuration'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                fa
                    ? 'Provider، مدل و اتصال API'
                    : 'Providers, models & API connection',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                fa
                    ? 'کلیدهای دسترسی در سمت سرور نگهداری می‌شوند و مقدار ذخیره‌شده هرگز به مرورگر برگردانده نمی‌شود.'
                    : 'Credentials are server-side only and stored values are never returned to the browser.',
              ),
              const SizedBox(height: 20),
              console.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(
                  fa
                      ? 'امکان دریافت تنظیمات وجود ندارد.'
                      : 'Configuration is unavailable.',
                ),
                data: (data) => data.providers.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            fa
                                ? 'هنوز Provider فعالی ثبت نشده است. فرم زیر را برای پیکربندی اولیه تکمیل کنید.'
                                : 'No provider is configured yet. Use the form below for initial setup.',
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final provider in data.providers)
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  provider.enabled
                                      ? Icons.smart_toy_outlined
                                      : Icons.pause_circle_outline,
                                ),
                                title: Text(provider.displayName),
                                subtitle: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${provider.adapter}\n${provider.baseUrl}',
                                  ),
                                ),
                                trailing: Tooltip(
                                  message: provider.credentialConfigured
                                      ? (fa
                                            ? 'کلید ثبت شده'
                                            : 'Credential configured')
                                      : (fa
                                            ? 'کلید ثبت نشده'
                                            : 'Credential missing'),
                                  child: Icon(
                                    provider.credentialConfigured
                                        ? Icons.verified_user_outlined
                                        : Icons.key_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              Text(
                fa
                    ? 'افزودن یا به‌روزرسانی Provider'
                    : 'Add or update provider',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _slugCtrl,
                      label: fa ? 'شناسه (slug)' : 'Slug',
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return fa ? 'الزامی' : 'Required';
                        }
                        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                          return fa
                              ? 'فقط حروف کوچک انگلیسی، عدد و _'
                              : 'Use lowercase letters, digits, underscore';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _displayNameCtrl,
                      label: fa ? 'نام نمایشی' : 'Display name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (fa ? 'الزامی' : 'Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: fa ? 'نوع Adapter' : 'Adapter',
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
                      label: fa ? 'Base URL' : 'Base URL',
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.url,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) {
                          return fa ? 'الزامی' : 'Required';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty) {
                          return fa
                              ? 'فقط آدرس HTTPS عمومی معتبر'
                              : 'Must be a valid public HTTPS URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _apiKeyCtrl,
                      label: fa
                          ? 'کلید API (فقط نوشتن)'
                          : 'API key (write-only)',
                      textDirection: TextDirection.ltr,
                      obscureText: true,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.length < 8) {
                          return fa
                              ? 'کلید باید حداقل ۸ نویسه باشد'
                              : 'Key must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fa ? 'فعال' : 'Enabled'),
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fa ? 'اولویت' : 'Priority'),
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
                      label: fa ? 'ذخیره Provider' : 'Save provider',
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
