import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_operations_repository.dart';

class AdminAiConfigPage extends ConsumerWidget {
  const AdminAiConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final console = ref.watch(adminConsoleProvider);
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
                style: Theme.of(context).textTheme.headlineMedium,
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
                                ? 'هنوز Provider فعالی ثبت نشده است. برای تحویل نهایی باید Provider سمت سرور پیکربندی شود.'
                                : 'No provider is configured yet. A server-side provider must be configured before final delivery.',
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
            ],
          ),
        ),
      ),
    );
  }
}
