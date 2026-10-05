import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/directional_icons.dart';
import '../../../../l10n/app_localizations.dart';

class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  l10n.adminCenterTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.adminCenterSubtitle),
                const SizedBox(height: 20),
                _AdminTile(
                  icon: Icons.key_outlined,
                  title: l10n.adminProviderConfigTitle,
                  subtitle: l10n.adminProviderConfigSubtitle,
                  onTap: () => context.go('/admin/ai-config'),
                ),
                _AdminTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: l10n.adminOperationsConsoleTitle,
                  subtitle: l10n.adminOperationsConsoleSubtitle,
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
      trailing: Icon(directionalChevron(context)),
      onTap: onTap,
    ),
  );
}
