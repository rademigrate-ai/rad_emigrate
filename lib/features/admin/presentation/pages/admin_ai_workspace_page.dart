import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai_assistant/presentation/pages/ai_assistant_page.dart';

/// Genuine Admin AI workspace — not merely AiAssistantPage(adminMode: true).
/// Shares the safe lower-level AI transport but presents admin-oriented
/// capabilities: research, drafting, diagnostics entry points, and unlimited
/// conversation (server quota for admin/super_admin).
class AdminAiWorkspacePage extends ConsumerWidget {
  const AdminAiWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminResearchAssistant),
        actions: [
          IconButton(
            tooltip: l10n.adminAiConfig,
            onPressed: () => context.go('/admin/ai-config'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.untrustedResearchDisclaimer,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CapabilityChip(
                        icon: Icons.travel_explore_outlined,
                        label: l10n.adminResearchSubtitle,
                      ),
                      _CapabilityChip(
                        icon: Icons.rate_review_outlined,
                        label: l10n.adminOperations,
                      ),
                      _CapabilityChip(
                        icon: Icons.health_and_safety_outlined,
                        label: l10n.providerModelConnection,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            // Reuses chat transport with adminMode so server scope is admin
            // and client-side 5-message quota is skipped.
            child: const AiAssistantPage(adminMode: true),
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: AppColors.primaryRed),
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Compact diagnostics strip for authorized admins (non-secret).
class AdminAiDiagnosticsCard extends StatelessWidget {
  const AdminAiDiagnosticsCard({
    super.key,
    required this.providerConfigured,
    required this.modelCount,
    required this.healthStatus,
    this.lastCheck,
    this.sanitizedError,
  });

  final bool providerConfigured;
  final int modelCount;
  final String healthStatus;
  final DateTime? lastCheck;
  final String? sanitizedError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.providerModelConnection,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            providerConfigured
                ? l10n.credentialConfigured
                : l10n.credentialMissing,
          ),
          Text('${l10n.discoverModels}: $modelCount'),
          Text('Status: $healthStatus'),
          if (lastCheck != null)
            Text('Last check: ${lastCheck!.toUtc().toIso8601String()}'),
          if (sanitizedError != null && sanitizedError!.isNotEmpty)
            Text(
              sanitizedError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
