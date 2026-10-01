import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../applications/domain/entities/application_status.dart';
import '../../../applications/presentation/providers/application_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/document_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final name = session?.fullName ?? 'Traveler';
    final apps = ref.watch(applicationControllerProvider).valueOrNull ?? [];
    final docs = ref.watch(documentControllerProvider).valueOrNull ?? [];
    final activeApps =
        apps.where((a) => a.status != ApplicationStatus.completed).length;
    final missingDocs = docs
        .where((d) => d.status == DocumentVerificationStatus.missing)
        .length;
    final profileDone = session?.profileComplete == true;

    final needsAction = !profileDone || missingDocs > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your journey'),
        actions: [
          IconButton(
            tooltip: 'AI Assistant',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.go('/ai-assistant'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppCard(
            emphasized: true,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $name', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  needsAction
                      ? 'A few items need your attention to keep your case moving.'
                      : 'Your case is on track. Review applications or ask the assistant.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(needsAction ? Icons.flag_outlined : Icons.check_circle_outline, size: 18, color: needsAction ? AppColors.warning : AppColors.success),
                    const SizedBox(width: 8),
                    Text(needsAction ? 'Next best step' : 'Everything looks good', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (needsAction) ...[
            SectionHeader(
              title: 'Needs your action',
              subtitle: 'Complete these to avoid delays',
            ),
            if (!profileDone)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => context.go('/profile-completion'),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete your profile',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Name and basic details are required',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                  ],
                ),
              ),
            if (missingDocs > 0)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => context.go('/documents'),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$missingDocs document${missingDocs == 1 ? '' : 's'} missing',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Upload required files for your application',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const StatusBadge(label: 'Action', tone: StatusTone.warning),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
          SectionHeader(
            title: 'Case overview',
            actionLabel: 'All cases',
            onAction: () => context.go('/applications'),
          ),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  value: '$activeApps',
                  label: 'Active cases',
                  onTap: () => context.go('/applications'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  value: '$missingDocs',
                  label: 'Docs missing',
                  onTap: () => context.go('/documents'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Quick actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                icon: Icons.public_outlined,
                label: 'Visa programs',
                onTap: () => context.go('/visa'),
              ),
              _ActionChip(
                icon: Icons.assignment_outlined,
                label: 'Applications',
                onTap: () => context.go('/applications'),
              ),
              _ActionChip(
                icon: Icons.folder_outlined,
                label: 'Documents',
                onTap: () => context.go('/documents'),
              ),
              _ActionChip(
                icon: Icons.smart_toy_outlined,
                label: 'AI assistant',
                onTap: () => context.go('/ai-assistant'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(title: 'Shortcuts'),
          AppCard(
            onTap: () => context.go('/profile'),
            margin: const EdgeInsets.only(bottom: 10),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline),
              title: Text('Profile'),
              subtitle: Text('Personal and immigration details'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          AppCard(
            onTap: () => context.go('/ai-assistant'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.smart_toy_outlined),
              title: Text('Ask the assistant'),
              subtitle: Text('Visas, documents, and process guidance'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.navy,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
    );
  }
}
