import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/motion_primitives.dart';
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
                  l10n.adminOperations,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.serverEnforcedAccessBody),
                const SizedBox(height: 20),
                MotionStagger(
                  index: 0,
                  child: _AdminTile(
                    icon: Icons.key_outlined,
                    title: l10n.adminAiConfig,
                    subtitle: l10n.providerModelConnection,
                    onTap: () => context.go('/admin/ai-config'),
                  ),
                ),
                MotionStagger(
                  index: 1,
                  child: _AdminTile(
                    icon: Icons.dashboard_customize_outlined,
                    title: l10n.adminOperations,
                    subtitle: l10n.operationalOverview,
                    onTap: () => context.go('/admin/operations'),
                  ),
                ),
                MotionStagger(
                  index: 2,
                  child: _AdminTile(
                    icon: Icons.support_agent_outlined,
                    title: l10n.adminConsultations,
                    subtitle: l10n.noAdminConsultations,
                    onTap: () => context.go('/admin/consultations'),
                  ),
                ),
                MotionStagger(
                  index: 3,
                  child: _AdminTile(
                    icon: Icons.travel_explore_outlined,
                    title: l10n.adminResearchAssistant,
                    subtitle: l10n.adminResearchSubtitle,
                    onTap: () => context.go('/admin/ai-research'),
                  ),
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
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, size: 30),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(subtitle),
      ),
      trailing: Icon(directionalChevron(context)),
    ),
  );
}
