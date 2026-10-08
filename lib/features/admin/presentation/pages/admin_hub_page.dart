import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';

class AdminHubPage extends StatelessWidget {
  const AdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _AdminDestination(
        icon: Icons.key_outlined,
        index: '01',
        title: l10n.adminAiConfig,
        subtitle: l10n.providerModelConnection,
        route: '/admin/ai-config',
      ),
      _AdminDestination(
        icon: Icons.dashboard_customize_outlined,
        index: '02',
        title: l10n.adminOperations,
        subtitle: l10n.operationalOverview,
        route: '/admin/operations',
      ),
      _AdminDestination(
        icon: Icons.support_agent_outlined,
        index: '03',
        title: l10n.adminConsultations,
        subtitle: l10n.noAdminConsultations,
        route: '/admin/consultations',
      ),
      _AdminDestination(
        icon: Icons.travel_explore_outlined,
        index: '04',
        title: l10n.adminResearchAssistant,
        subtitle: l10n.adminResearchSubtitle,
        route: '/admin/ai-research',
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminOperations)),
      body: PremiumCanvas(
        dark: true,
        accent: AppColors.teal,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PremiumHeroPanel(
                    kicker: const EditorialKicker(
                      index: '06',
                      label: 'OPERATIONS CONSOLE',
                      dark: true,
                    ),
                    title: l10n.adminOperations,
                    body: l10n.serverEnforcedAccessBody,
                    trailing: const RadOrbit(size: 185, showBrand: false),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 700;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (var index = 0; index < items.length; index++)
                            SizedBox(
                              width: wide
                                  ? (constraints.maxWidth - 14) / 2
                                  : constraints.maxWidth,
                              child: MotionStagger(
                                index: index,
                                child: _AdminDeckCard(
                                  item: items[index],
                                  onTap: () => context.go(items[index].route),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.icon,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String index;
  final String title;
  final String subtitle;
  final String route;
}

class _AdminDeckCard extends StatelessWidget {
  const _AdminDeckCard({required this.item, required this.onTap});

  final _AdminDestination item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: const Color(0xFF0D2B37),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.index,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF74E2DB),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Icon(item.icon, color: const Color(0xFF74E2DB), size: 25),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: const Color(0xFFBDD2D8)),
                ),
                const SizedBox(height: 24),
                Icon(directionalChevron(context), color: AppColors.primaryRed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
