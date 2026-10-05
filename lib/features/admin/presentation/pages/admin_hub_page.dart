import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminOperations)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  fa ? 'مرکز مدیریت راد' : 'RAD Admin Center',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  fa
                      ? 'تنظیمات هوش مصنوعی، منابع، پژوهش، بازبینی و عملیات از این بخش مدیریت می‌شوند.'
                      : 'Manage AI configuration, sources, research, review, and operations from one place.',
                ),
                const SizedBox(height: 20),
                _AdminTile(
                  icon: Icons.key_outlined,
                  title: fa
                      ? 'تنظیم Provider و API'
                      : 'Provider & API configuration',
                  subtitle: fa
                      ? 'Base URL، Provider و کلید دسترسی را بدون نمایش دوباره کلید ذخیره کنید.'
                      : 'Configure provider, Base URL and credential without exposing stored secrets.',
                  onTap: () => context.go('/admin/ai-config'),
                ),
                _AdminTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: fa ? 'کنسول عملیات' : 'Operations console',
                  subtitle: fa
                      ? 'مدل‌ها، منابع، پژوهش، صف بازبینی، Feed و سلامت سیستم.'
                      : 'Models, sources, research, review queue, Feed and system health.',
                  onTap: () => context.go('/admin/operations'),
                ),
                _AdminTile(
                  icon: Icons.travel_explore_outlined,
                  title: l10n.adminResearchAssistant,
                  subtitle: l10n.adminResearchSubtitle,
                  onTap: () => context.go('/admin/ai-research'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, size: 30),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
